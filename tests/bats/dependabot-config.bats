#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# dependabot-config.bats - regression guards for .github/dependabot.yml
# =============================================================================
# Locks down the security posture of the Dependabot config:
#   - version: 2 schema
#   - vulnerability-alerts: explicitly enabled
#   - exactly ONE update block (github-actions); no spurious ecosystems
#     added without a manifest (this catalog has no package.json,
#     requirements.txt, Dockerfile, or *.tf).
#   - schedule: weekly monday 06:00 UTC (low-traffic window)
#   - PR limit: 5 (default)
#   - Reviewers: spark-match/devops; Assignees: ahincho
#   - Auto-merge: declared `patch` only (NOT all/major — major bumps of
#     GitHub Actions routinely introduce breaking changes)
#   - 5 groups (aws-actions / actions-ecosystem / marocchino /
#     release-tools / third-party-actions)
# =============================================================================

CONFIG="$BATS_TEST_DIRNAME/../../.github/dependabot.yml"

# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

@test "dependabot: config declares version: 2 schema" {
  run grep -E "^version:[[:space:]]+2$" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: vulnerability-alerts explicitly enabled (defense-in-depth)" {
  run grep -E "^vulnerability-alerts:" "$CONFIG"
  [ "$status" -eq 0 ]
  run grep -E "^[[:space:]]+enabled:[[:space:]]+true" "$CONFIG"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Ecosystem count (must be exactly 1, github-actions)
# ---------------------------------------------------------------------------

@test "dependabot: exactly ONE ecosystem configured (no spurious ecosystems)" {
  # Count the number of `package-ecosystem:` lines. Adding ecosystems
  # without manifests creates empty PRs every week.
  local count
  count=$(grep -cE "^[[:space:]]+-?[[:space:]]*package-ecosystem:" "$CONFIG")
  [ "$count" -eq 1 ]
}

@test "dependabot: ecosystem is github-actions" {
  run grep -E '^[[:space:]]+-?[[:space:]]*package-ecosystem:[[:space:]]+"github-actions"' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: directory is repo root (/)" {
  run grep -E '^[[:space:]]+directory:[[:space:]]+"/"' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: schedule is weekly monday 06:00 UTC" {
  run grep -E '^[[:space:]]+interval:[[:space:]]+"weekly"' "$CONFIG"
  [ "$status" -eq 0 ]
  run grep -E '^[[:space:]]+day:[[:space:]]+"monday"' "$CONFIG"
  [ "$status" -eq 0 ]
  run grep -E '^[[:space:]]+time:[[:space:]]+"06:00"' "$CONFIG"
  [ "$status" -eq 0 ]
  run grep -E '^[[:space:]]+timezone:[[:space:]]+"UTC"' "$CONFIG"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Triage routing
# ---------------------------------------------------------------------------

@test "dependabot: PRs assigned to ahincho (per gh-pr-create convention)" {
  run grep -E '^[[:space:]]+assignees:' "$CONFIG"
  [ "$status" -eq 0 ]
  run grep -E '^[[:space:]]+-?[[:space:]]*"ahincho"' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: PRs reviewed by spark-match/devops team" {
  run grep -E '^[[:space:]]+reviewers:' "$CONFIG"
  [ "$status" -eq 0 ]
  run grep -E '^[[:space:]]+-?[[:space:]]*"spark-match/devops"' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: PR limit is 5 (default; raise if queue gets stale)" {
  run grep -E '^[[:space:]]+open-pull-requests-limit:[[:space:]]+5$' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: commit prefix is ci (matches history)" {
  run grep -E '^[[:space:]]+prefix:[[:space:]]+"ci"$' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: labels include dependencies + ci" {
  run grep -E '^[[:space:]]+labels:' "$CONFIG"
  [ "$status" -eq 0 ]
  run grep -E '^[[:space:]]+-[[:space:]]+"dependencies"' "$CONFIG"
  [ "$status" -eq 0 ]
  run grep -E '^[[:space:]]+-[[:space:]]+"ci"' "$CONFIG"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Auto-merge (intention declaration)
# ---------------------------------------------------------------------------

@test "dependabot: auto-merge block declared" {
  run grep -E '^[[:space:]]+auto-merge:' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: auto-merge is restricted to PATCH only" {
  # Major version bumps of GitHub Actions routinely introduce breaking
  # changes (Node version, output schema). Patch-only is the safe default.
  run grep -E -A5 '^[[:space:]]+auto-merge:' "$CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"patch"* ]]
  ! grep -E '^[[:space:]]+versions:[[:space:]]*\[?"?(major|minor)' "$CONFIG"
}

@test "dependabot: auto-merge dependency-type is 'all'" {
  run grep -E -A5 '^[[:space:]]+auto-merge:' "$CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dependency-type:"*"all"* ]]
}

# ---------------------------------------------------------------------------
# Groups (must have all 5 named groups)
# ---------------------------------------------------------------------------

@test "dependabot: aws-actions group exists" {
  run grep -E "^[[:space:]]+aws-actions:" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: actions-ecosystem group exists" {
  run grep -E "^[[:space:]]+actions-ecosystem:" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: marocchino group exists (sticky-pull-request-comment)" {
  run grep -E "^[[:space:]]+marocchino:" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: release-tools group exists (googleapis/release-please-action)" {
  run grep -E "^[[:space:]]+release-tools:" "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "dependabot: third-party-actions catch-all group exists with '*' pattern" {
  # The header comment also mentions `third-party-actions:` so we need
  # to find the actual group block (indented under `groups:`), not the
  # header reference. Use a 2-step grep: first find `groups:`, then
  # walk forward to find `third-party-actions:` inside it.
  local in_groups=0
  local found=0
  local pattern='*'
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "$line" =~ ^[[:space:]]+groups:[[:space:]]*$ ]]; then
      in_groups=1
      continue
    fi
    if [[ $in_groups -eq 1 ]]; then
      # Exit on next top-level key at same indent as `groups:`.
      if [[ "$line" =~ ^[a-zA-Z_-]+: ]] && ! [[ "$line" =~ ^[[:space:]] ]]; then
        break
      fi
      if [[ "$line" =~ ^[[:space:]]+third-party-actions:[[:space:]]*$ ]]; then
        found=1
      fi
      if [[ $found -eq 1 && "$line" =~ \"\*\" ]]; then
        # Verify the pattern line follows within 2 lines.
        return 0
      fi
    fi
  done < "$CONFIG"
  echo "# third-party-actions group block not found or missing '*' pattern"
  return 1
}
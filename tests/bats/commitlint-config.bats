#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# commitlint-config.bats - regression guards for .commitlintrc.json
# =============================================================================
# Locks down the structure of the canonical commitlint config so that:
#   - .commitlintrc.json is valid JSON and loadable by commitlint
#   - the @commitlint/config-conventional base is extended (so default
#     rules like header-max-length are inherited)
#   - the type-enum is exactly the 10 Conventional Commits types we allow
#   - the scope-enum matches the 12 scopes documented in AGENTS.md § 3
#   - .githooks/commit-msg reflects the same allowlists (drift detector:
#     if you add a scope to one, you must add it to the other)
#
# The local hook .githooks/commit-msg is pure-bash + grep (no Node, no
# commitlint binary install required). It duplicates a subset of the CI
# commitlint check. These tests guard against drift between the two.
# =============================================================================

CONFIG="$BATS_TEST_DIRNAME/../../.commitlintrc.json"
HOOK="$BATS_TEST_DIRNAME/../../.githooks/commit-msg"

# ---------------------------------------------------------------------------
# .commitlintrc.json structure
# ---------------------------------------------------------------------------

@test "commitlint-config: file exists at repo root" {
  [ -f "$CONFIG" ]
}

@test "commitlint-config: valid JSON" {
  jq . "$CONFIG" >/dev/null
}

@test "commitlint-config: extends @commitlint/config-conventional" {
  run jq -r '.extends[]' "$CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"@commitlint/config-conventional"* ]]
}

@test "commitlint-config: type-enum contains the 10 conventional types" {
  # 10 = feat, fix, chore, docs, refactor, test, build, ci, perf, revert
  COUNT=$(jq -r '.rules["type-enum"][2] | length' "$CONFIG")
  [ "$COUNT" -eq 10 ]

  for t in feat fix chore docs refactor test build ci perf revert; do
    jq -e --arg t "$t" '.rules["type-enum"][2] | index($t) != null' "$CONFIG" >/dev/null \
      || { echo "missing type: $t"; return 1; }
  done
}

@test "commitlint-config: scope-enum contains the 12 org-approved scopes" {
  # 12 = composite, workflows, ecosystem, node, deploy, governance,
  #      scripts, docs, ci, quality, reconciler, repo
  COUNT=$(jq -r '.rules["scope-enum"][2] | length' "$CONFIG")
  [ "$COUNT" -eq 12 ]

  for s in composite workflows ecosystem node deploy governance scripts docs ci quality reconciler repo; do
    jq -e --arg s "$s" '.rules["scope-enum"][2] | index($s) != null' "$CONFIG" >/dev/null \
      || { echo "missing scope: $s"; return 1; }
  done
}

@test "commitlint-config: scope-empty is disabled (level 0) so scope is optional" {
  LEVEL=$(jq -r '.rules["scope-empty"][0]' "$CONFIG")
  [ "$LEVEL" -eq 0 ]
}

@test "commitlint-config: scope-enum is enabled (level 2, always) so values are validated when scope is present" {
  LEVEL=$(jq -r '.rules["scope-enum"][0]' "$CONFIG")
  APPLY=$(jq -r '.rules["scope-enum"][1]' "$CONFIG")
  [ "$LEVEL" -eq 2 ]
  [ "$APPLY" = "always" ]
}

@test "commitlint-config: subject-case is lower-case" {
  jq -e '.rules["subject-case"] == [2, "always", "lower-case"]' "$CONFIG" >/dev/null
}

@test "commitlint-config: subject-full-stop is never '.'" {
  jq -e '.rules["subject-full-stop"] == [2, "never", "."]' "$CONFIG" >/dev/null
}

@test "commitlint-config: header-max-length is 100" {
  jq -e '.rules["header-max-length"] == [2, "always", 100]' "$CONFIG" >/dev/null
}

@test "commitlint-config: body-max-line-length is disabled (level 0)" {
  # body-max-line-length is disabled (level 0) so Dependabot's long
  # auto-generated body lines (with changelog URLs, semver bumps, etc.)
  # pass. The header is still capped at 100 via header-max-length.
  LEVEL=$(jq -r '.rules["body-max-line-length"][0]' "$CONFIG")
  [ "$LEVEL" -eq 0 ]
}

@test "commitlint-config: has helpUrl pointing at AGENTS.md" {
  run jq -r '.helpUrl' "$CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AGENTS.md"* ]]
}

# ---------------------------------------------------------------------------
# .githooks/commit-msg mirror (drift detector)
# ---------------------------------------------------------------------------

@test "commitlint-config: .githooks/commit-msg exists" {
  [ -f "$HOOK" ]
}

@test "commitlint-config: hook is executable (chmod +x applied)" {
  [ -x "$HOOK" ]
}

@test "commitlint-config: hook header lists the same 10 types as commitlintrc" {
  # Extract the case pattern from the hook and grep a known good message
  # through it; should exit 0. If a type were missing from the hook's
  # allowlist, this would fail.
  run bash -c '
    for t in feat fix chore docs refactor test build ci perf revert; do
      echo -e "$t(workflows): subject" | "'"$HOOK"'" /dev/stdin >/dev/null 2>&1 \
        || { echo "hook rejected type: $t"; exit 1; }
    done
  '
  [ "$status" -eq 0 ]
}

@test "commitlint-config: hook header lists the same 12 scopes as commitlintrc" {
  run bash -c '
    for s in composite workflows ecosystem node deploy governance scripts docs ci quality reconciler repo; do
      echo -e "chore($s): subject" | "'"$HOOK"'" /dev/stdin >/dev/null 2>&1 \
        || { echo "hook rejected scope: $s"; exit 1; }
    done
  '
  [ "$status" -eq 0 ]
}

@test "commitlint-config: hook rejects a non-allowlisted type" {
  run bash -c '
    echo -e "garbage(scope): subject" | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"type 'garbage' not in allowlist"* ]]
}

@test "commitlint-config: hook rejects a non-allowlisted scope" {
  run bash -c '
    echo -e "chore(garbage): subject" | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"scope 'garbage' not in allowlist"* ]]
}

@test "commitlint-config: hook accepts type without scope (e.g. 'docs: subject')" {
  run bash -c '
    echo -e "docs: clarifying sentence" | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -eq 0 ]
}

@test "commitlint-config: hook rejects subject ending with period" {
  run bash -c '
    echo -e "fix(workflows): bad subject." | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"must not end with '.'"* ]]
}

@test "commitlint-config: hook rejects subject with uppercase letters" {
  run bash -c '
    echo -e "fix(workflows): Bad Subject" | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be lowercase"* ]]
}

@test "commitlint-config: hook rejects header > 100 chars" {
  LONG_SUBJECT=$(printf 'x%.0s' {1..110})
  run bash -c '
    echo -e "fix(workflows): '"$LONG_SUBJECT"'" | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"max 100"* ]]
}

@test "commitlint-config: hook allows Merge commits to pass through" {
  run bash -c '
    echo -e "Merge branch '\''feat/x'\'' into main" | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -eq 0 ]
}

@test "commitlint-config: hook allows Revert commits to pass through" {
  run bash -c '
    echo -e "Revert \"feat(workflows): add x\"" | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -eq 0 ]
}

@test "commitlint-config: hook rejects header with wrong shape" {
  run bash -c '
    echo -e "no type here" | "'"$HOOK"'" /dev/stdin
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not match"* ]]
}

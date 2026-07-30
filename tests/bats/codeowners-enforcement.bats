#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# codeowners-enforcement.bats - regression guards for CODEOWNERS + ruleset
# =============================================================================
# Locks down the security posture of CODE_OWNERS review enforcement:
#
#   - .github/CODEOWNERS exists at the canonical location.
#   - NO catch-all `*` pattern (every path must be listed explicitly).
#   - Every top-level directory in the repo has at least one owner entry.
#   - Every top-level file in the repo (e.g. LICENSE, README.md) has at
#     least one owner entry.
#   - Owners are always @spark-match/devops (the team that actually owns
#     this catalog), optionally co-owned with @spark-match/product-owners
#     for governance docs.
#   - No bare usernames (e.g. `@ahincho`) as the only owner of a path.
#     Teams are enforced; individuals drift.
#
# Ruleset enforcement is verified separately via the GitHub API at
# `gh api repos/spark-match/spark-match-01-devops/rulesets/18893014`,
# which lives in scripts/audit-codeowners-ruleset.sh. This bats file
# covers the FILE-side invariants; the API-side check is run manually
# or via the dedicated audit script.
# =============================================================================

CODEOWNERS="$BATS_TEST_DIRNAME/../../.github/CODEOWNERS"

# Helper: list all top-level entries (directories and files) in the repo.
# Excludes .git/ (not tracked).
list_top_level_paths() {
  git -C "$BATS_TEST_DIRNAME/../.." ls-files \
    | awk -F/ '{print $1"/"}' \
    | sort -u
}

# Helper: list all top-level files (no nested directories).
list_top_level_files() {
  git -C "$BATS_TEST_DIRNAME/../.." ls-files \
    | awk -F/ 'NF==1 || ($1 != "" && $2 == "")' \
    | sort -u
}

# Helper: list all top-level directories (paths starting with "<dir>/").
list_top_level_dirs() {
  git -C "$BATS_TEST_DIRNAME/../.." ls-files \
    | awk -F/ 'NF>=2 {print $1"/"; exit}' \
    | sort -u
}

# Extract the path pattern (column 1) from a CODEOWNERS line. Lines
# starting with # are comments. Lines like `# ====` are headers.
# Returns 0 if a path was extracted, 1 if the line is a comment.
extract_codeowners_path() {
  local line="$1"
  # Skip comments and blank lines.
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && return 1
  # First whitespace-separated field is the path.
  echo "$line" | awk '{print $1}'
  return 0
}

# ---------------------------------------------------------------------------
# Existence + canonical location
# ---------------------------------------------------------------------------

@test "CODEOWNERS: exists at .github/CODEOWNERS (canonical GitHub location)" {
  [ -f "$CODEOWNERS" ]
}

@test "CODEOWNERS: no stale copy at root /CODEOWNERS (legacy location)" {
  # GitHub reads .github/CODEOWNERS first; if both exist the .github/
  # version wins. A stale root copy causes confusion.
  [ ! -f "$BATS_TEST_DIRNAME/../../CODEOWNERS" ] || {
    echo "# Stale /CODEOWNERS file at repo root"
    return 1
  }
}

# ---------------------------------------------------------------------------
# No catch-all pattern
# ---------------------------------------------------------------------------

@test "CODEOWNERS: no catch-all '*' pattern (paths must be explicit)" {
  # A catch-all '*' causes GitHub to ACCUMULATE owners for every other
  # matching rule, which silently broadens review scope. The header
  # comment in CODEOWNERS explicitly forbids this.
  if grep -E '^[[:space:]]+\*[[:space:]]+@' "$CODEOWNERS"; then
    echo "# CODEOWNERS contains a catch-all '*' pattern"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Coverage of top-level paths
# ---------------------------------------------------------------------------

@test "CODEOWNERS: every top-level directory in the repo has at least one owner entry" {
  # For each top-level directory D/ in the repo, there must be a
  # CODEOWNERS line whose path is `/D/` or matches it.
  local missing=()
  for dir in $(list_top_level_dirs); do
    # CODEOWNERS uses patterns like `/.github/` (with leading slash
    # for absolute-from-root) so we look for that form.
    if ! grep -E "^/${dir}[[:space:]]" "$CODEOWNERS" >/dev/null 2>&1; then
      missing+=("$dir")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "# Top-level directories with no CODEOWNERS entry:"
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "CODEOWNERS: every top-level file in the repo has at least one owner entry" {
  local missing=()
  for file in $(list_top_level_files); do
    if ! grep -E "^/${file}[[:space:]]" "$CODEOWNERS" >/dev/null 2>&1; then
      missing+=("$file")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "# Top-level files with no CODEOWNERS entry:"
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Owner discipline
# ---------------------------------------------------------------------------

@test "CODEOWNERS: every owner entry references @spark-match/* (no bare users)" {
  # Owners must be teams (@spark-match/...), not individuals. Teams are
  # stable; individuals drift (departures, role changes). The only
  # exception we allow is the explicit header comment.
  local offenders=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Extract owner tokens (start with @).
    for token in $(echo "$line" | grep -oE '@[a-zA-Z0-9_./-]+'); do
      if [[ "$token" != @spark-match/* ]]; then
        offenders+=("$line  (offender: $token)")
      fi
    done
  done < "$CODEOWNERS"
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "# CODEOWNERS uses non-team owners:"
    printf '  %s\n' "${offenders[@]}"
    return 1
  fi
}

@test "CODEOWNERS: @spark-match/devops is owner of every path (canonical team)" {
  # Every CODEOWNERS rule must include @spark-match/devops. This is the
  # team that actually owns the catalog. @spark-match/product-owners may
  # co-own governance docs but devops must always be there.
  local missing=()
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if ! echo "$line" | grep -q '@spark-match/devops'; then
      missing+=("line $line_num: $line")
    fi
  done < "$CODEOWNERS"
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "# CODEOWNERS lines missing @spark-match/devops:"
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Header invariants
# ---------------------------------------------------------------------------

@test "CODEOWNERS: header documents the required approval count + code-owner review" {
  run grep -E "required_approving_review_count:[[:space:]]+1" "$CODEOWNERS"
  [ "$status" -eq 0 ]
  run grep -E "require_code_owner_review:[[:space:]]+true" "$CODEOWNERS"
  [ "$status" -eq 0 ]
}

@test "CODEOWNERS: header lists the CODE OWNERS teams (devops + product-owners)" {
  run grep -E "@spark-match/devops" "$CODEOWNERS"
  [ "$status" -eq 0 ]
  run grep -E "@spark-match/product-owners" "$CODEOWNERS"
  [ "$status" -eq 0 ]
}

@test "CODEOWNERS: header explains the no-catch-all convention" {
  run grep -E "catch-all|NO usamos catch-all" "$CODEOWNERS"
  [ "$status" -eq 0 ]
}

@test "CODEOWNERS: header warns that PR author cannot self-approve" {
  run grep -E "no puede aprobar su propio PR|self.approve" "$CODEOWNERS"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Audit-trail invariant
# ---------------------------------------------------------------------------

@test "CODEOWNERS: header mentions the last-audit date (audit trail)" {
  # Look for "Ultima auditoria:" or "Last audit:" in the header.
  run grep -iE "auditoria|audit" "$CODEOWNERS"
  [ "$status" -eq 0 ]
}
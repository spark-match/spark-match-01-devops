#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# merge-methods.bats - configure-merge-methods.sh test suite
# =============================================================================
# Regression guard for the cluster of bugs fixed in PR-2:
#   - --help used to exit 1 (treating help as an error).
#   - booleans were sent via -f (string) instead of -F (typed JSON),
#     which meant allow_merge_commit/allow_rebase_merge were set to
#     the strings "true"/"false" rather than JSON booleans, and the
#     API silently enabled the disabled merge methods.
#   - `mapfile -t REPOS < <(gh api ...)` silently dropped gh failures
#     (process substitution runs in a subshell that set -e does not
#     observe), leaving REPOS empty and the script exiting 0.
#   - PATCH failures were swallowed by `2>/dev/null` with no per-repo
#     tracking, so the script exited 0 even if every PATCH failed.
# =============================================================================

load 'helpers/merge-methods'

setup() {
  load 'helpers/merge-methods'
  cd "$BATS_TEST_TMPDIR"
  : > gh.log
  rm -f list-fail patch-fail repos-empty
}

teardown() {
  :
}

# -----------------------------------------------------------------------------
# Help + argument parsing
# -----------------------------------------------------------------------------

@test "--help exits 0 (was: exit 1; help is not an error)" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  # The usage() sed extracts lines 2..first `# ====` line; the first
  # non-comment lines in the script header are SPDX + Copyright, both of
  # which are part of the usage banner.
  [[ "$output" == *"SPDX-License-Identifier"* ]]
  [[ "$output" == *"Copyright (C) 2026 Spark Match"* ]]
}

@test "-h is an alias of --help (also exits 0)" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
}

@test "unknown arg -> exit 2 (per gh-cli convention; not 0 or 1)" {
  run bash "$SCRIPT" --nonexistent
  [ "$status" -eq 2 ]
  [[ "$output" == *"argumento desconocido"* ]]
}

# -----------------------------------------------------------------------------
# -F vs -f (typed vs string booleans)
# -----------------------------------------------------------------------------

@test "PATCH uses -F (typed JSON) for booleans, NOT -f (string)" {
  run bash "$SCRIPT" --repos spark-match-foo
  [ "$status" -eq 0 ]
  grep -q "gh api -X PATCH.*-F allow_merge_commit=false" gh.log
  grep -q "gh api -X PATCH.*-F allow_rebase_merge=false" gh.log
  grep -q "gh api -X PATCH.*-F allow_squash_merge=true" gh.log
}

@test "--allow-merge sends allow_merge_commit=true (typed JSON, not string)" {
  run bash "$SCRIPT" --repos spark-match-foo --allow-merge
  [ "$status" -eq 0 ]
  grep -q "gh api -X PATCH.*-F allow_merge_commit=true" gh.log
}

# -----------------------------------------------------------------------------
# Repo listing + scope
# -----------------------------------------------------------------------------

@test "--repos skips the org listing call" {
  run bash "$SCRIPT" --repos spark-match-foo
  [ "$status" -eq 0 ]
  ! grep -q "gh api.*orgs/spark-match/repos" gh.log
}

@test "no --repos -> listing call issued, PATCH issued per repo" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "gh api orgs/spark-match/repos" gh.log
  grep -q "gh api -X PATCH repos/spark-match/spark-match-foo" gh.log
  grep -q "gh api -X PATCH repos/spark-match/spark-match-bar" gh.log
}

@test "listing failure -> script exits 1 (was: exit 0, REPOS empty)" {
  touch list-fail
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no se pudo listar"* ]]
}

@test "listing returns empty -> script exits 1 (no work to do)" {
  touch repos-empty
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no tiene repos"* ]]
}

# -----------------------------------------------------------------------------
# PATCH failure tracking
# -----------------------------------------------------------------------------

@test "PATCH failure -> script exits 1 (was: exit 0, swallowed by 2>/dev/null)" {
  touch patch-fail
  run bash "$SCRIPT" --repos spark-match-foo
  [ "$status" -eq 1 ]
  [[ "$output" == *"PATCH rejected"* ]]
  [[ "$output" == *"spark-match-foo"* ]]
}

# -----------------------------------------------------------------------------
# Dry-run
# -----------------------------------------------------------------------------

@test "--dry-run issues GET per repo, no PATCH" {
  run bash "$SCRIPT" --repos spark-match-foo --dry-run
  [ "$status" -eq 0 ]
  grep -q "gh api repos/spark-match/spark-match-foo" gh.log
  ! grep -q "gh api -X PATCH" gh.log
}
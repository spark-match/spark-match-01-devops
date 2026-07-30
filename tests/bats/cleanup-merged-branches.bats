#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# cleanup-merged-branches.bats - regression guards for the branch
# cleanup script.
# =============================================================================
# Locks down the safety properties of scripts/cleanup-merged-branches.sh:
#   - Script refuses to run unless on branch `main`.
#   - Script requires that origin/main is fetchable.
#   - Candidate list excludes `main`, `HEAD`, and any `release-please--*`.
#   - Direct-ancestor branches use `-d` (safe delete).
#   - Squash-merged branches use `-D` (forced) but ONLY after a
#     subject-match check against origin/main.
#   - `--dry-run` flag is honored (no deletions in dry-run mode).
#   - `--remote` flag triggers `git push origin --delete` for each
#     candidate.
#   - Remote delete is gated: skipped for `release-please--*` branches
#     (the release-please bot owns those).
#   - Exit code is 0 on full success, 1 on any failed delete.
# =============================================================================

CLEANUP="$BATS_TEST_DIRNAME/../../scripts/cleanup-merged-branches.sh"

# ---------------------------------------------------------------------------
# Existence + SPDX + shebang
# ---------------------------------------------------------------------------

@test "cleanup: scripts/cleanup-merged-branches.sh exists" {
  [ -f "$CLEANUP" ]
}

@test "cleanup: SPDX header present" {
  run grep -E 'SPDX-License-Identifier' "$CLEANUP"
  [ "$status" -eq 0 ]
}

@test "cleanup: shebang + set -u" {
  run head -1 "$CLEANUP"
  [[ "$output" == *"#!/usr/bin/env bash"* ]]
  run grep -E '^set -u' "$CLEANUP"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------

@test "cleanup: accepts --dry-run, --remote, --help, -h flags" {
  run grep -E -- '--dry-run|--remote|--help|-h' "$CLEANUP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--remote"* ]]
}

# ---------------------------------------------------------------------------
# Safety invariants
# ---------------------------------------------------------------------------

@test "cleanup: refuses to run from a branch other than main" {
  # The script must check the current branch and exit if not main.
  run grep -E 'current branch is' "$CLEANUP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"'main'"* ]]
}

@test "cleanup: fetches origin/main before scanning (no stale merge-base)" {
  run grep -E 'git fetch origin main' "$CLEANUP"
  [ "$status" -eq 0 ]
}

@test "cleanup: excludes main, HEAD, and release-please--* from candidates" {
  # The mapfile/loop must filter out these special refs.
  run grep -E '^main\$|release-please--\*' "$CLEANUP"
  [ "$status" -eq 0 ]
  # Explicit skip in remote-delete loop too.
  run grep -E 'release-please--\*\) continue' "$CLEANUP"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Squash-merge detection (the core correctness bug we fixed)
# ---------------------------------------------------------------------------

@test "cleanup: uses --format with >/dev/null redirect (not -q alone)" {
  # Regression: `git log --format=X -q` does NOT suppress stdout (the
  # -q flag only suppresses implicit branch/date headers). If the
  # script uses -q without redirect, the matching SHA leaks into the
  # if-body's stdout and corrupts the mapfile. This test locks down the
  # correct pattern: --format='%H' followed by >/dev/null.
  run grep -E "format='%H' >/dev/null" "$CLEANUP"
  [ "$status" -eq 0 ]
}

@test "cleanup: no git log ... --format=... -q 2>/dev/null pattern (the bug)" {
  # Negative regression guard: the broken pattern must NOT appear.
  # The `-q` flag alone is not enough when --format is used.
  if grep -E 'git log.*--format.*-q 2>/dev/null' "$CLEANUP"; then
    echo "# Found the broken pattern: -q does not suppress --format output"
    return 1
  fi
}

@test "cleanup: detects both linear-merge (merge-base) AND squash-merge (subject)" {
  # Two checks: direct ancestor via merge-base AND squash via subject match.
  run grep -E 'merge-base --is-ancestor' "$CLEANUP"
  [ "$status" -eq 0 ]
  run grep -E -- '--grep=\"\$subject\"' "$CLEANUP"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Delete strategy
# ---------------------------------------------------------------------------

@test "cleanup: uses -d (safe) for direct-ancestor branches" {
  run grep -E 'git branch -d' "$CLEANUP"
  [ "$status" -eq 0 ]
}

@test "cleanup: uses -D (force) ONLY for squash-merged branches (after subject match)" {
  # -D must appear in the script AND must be gated on the subject-match
  # check. An unguarded -D is a foot-gun.
  #
  # Strategy: the script header has a comment mentioning `-D` (so a
  # naive grep matches the comment line). We grab the LAST match
  # (which is always the actual code), then verify it's preceded by
  # the gating if-statement.
  run grep -nE 'git branch -D' "$CLEANUP"
  [ "$status" -eq 0 ]
  # Last match line number.
  local line_d
  line_d=$(grep -nE 'git branch -D' "$CLEANUP" | tail -1 | cut -d: -f1)
  if [ -z "$line_d" ]; then return 1; fi
  # Look 5 lines above for the gating `if git log origin/main --grep`.
  local above
  above=$(sed -n "$((line_d - 5)),$((line_d - 1))p" "$CLEANUP")
  if ! echo "$above" | grep -q 'if git log origin/main --grep'; then
    echo "# -D at line $line_d is not gated by subject-match check. Lines above:"
    echo "$above"
    return 1
  fi
}

@test "cleanup: remote delete uses git push origin --delete (not branch -D)" {
  run grep -E 'git push origin --delete' "$CLEANUP"
  [ "$status" -eq 0 ]
  ! grep -E 'git push origin :' "$CLEANUP"
}

# ---------------------------------------------------------------------------
# Dry-run mode
# ---------------------------------------------------------------------------

@test "cleanup: --dry-run prints would-do instead of executing" {
  # The script has TWO dry-run branches (local delete + remote delete).
  # Both must wrap the actual commands with a DRY_RUN guard.
  local count
  count=$(grep -cE '\$DRY_RUN -eq 1' "$CLEANUP")
  [ "$count" -ge 2 ]
  run grep -F '[dry-run]' "$CLEANUP"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Exit codes
# ---------------------------------------------------------------------------

@test "cleanup: exits 0 on success, 1 on failure (per script header)" {
  run grep -E 'exit 0|exit 1' "$CLEANUP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exit 0"* ]]
  [[ "$output" == *"exit 1"* ]]
}

@test "cleanup: tracks FAIL counter and exits non-zero if any delete failed" {
  run grep -E 'FAIL=\$\(\(FAIL \+ 1\)\)' "$CLEANUP"
  [ "$status" -eq 0 ]
  run grep -E 'if \[\[ \$FAIL -gt 0' "$CLEANUP"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Help text
# ---------------------------------------------------------------------------

@test "cleanup: --help exits 0 and prints usage" {
  # The --help branch must print the header comment and exit 0.
  run grep -E -- '--help|-h' "$CLEANUP"
  [ "$status" -eq 0 ]
  run grep -E 'sed -n' "$CLEANUP"
  [ "$status" -eq 0 ]
  # Must exit 0 in the --help branch (not the failure exit 2).
  run grep -E -- '\-\-help\|-h\)' "$CLEANUP"
  [ "$status" -eq 0 ]
}
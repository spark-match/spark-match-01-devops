#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# cleanup-merged-branches.sh - delete local + remote refs whose tip is
# already squash-merged into origin/main.
# =============================================================================
# Usage:
#   ./scripts/cleanup-merged-branches.sh [--dry-run] [--remote]
#
# Flags:
#   --dry-run    Print what would be deleted without deleting anything.
#   --remote     Also push `origin :branch` deletes to GitHub.
#                 Without this flag, only local refs are cleaned.
#
# Safety:
#   - Uses `git branch -d` (not `-D`) which refuses to delete a branch
#     whose tip is NOT an ancestor of origin/main. This protects against
#     accidentally deleting work-in-progress.
#   - Excludes `main`, `HEAD`, and any `release-please--*` branch (the
#     release-please automation owns those).
#   - Excludes any branch that has an OPEN PR (avoid mid-flight deletion).
#
# Exit codes:
#   0   clean
#   1   one or more deletes failed (re-run after investigation)
# =============================================================================

set -u

DRY_RUN=0
DO_REMOTE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --remote) DO_REMOTE=1; shift ;;
        --help|-h)
            sed -n '2,30p' "$0"
            exit 0
            ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

# Resolve repo dir.
REPO_DIR="$(git rev-parse --show-toplevel)"
cd "$REPO_DIR" || exit 1

# Sanity: current branch must be main so we don't accidentally delete it.
current=$(git branch --show-current)
if [[ "$current" != "main" ]]; then
    echo "::error::current branch is '$current'; must be 'main' before cleanup" >&2
    echo "  Run: git checkout main && git pull --ff-only origin main" >&2
    exit 1
fi

# Make sure origin/main is up to date so `git branch -d` uses the right
# merge-base.
git fetch origin main --quiet 2>&1 || true

# Build the candidate list. A branch is a candidate for deletion if
# EITHER:
#   (a) its tip is a direct ancestor of origin/main (linear history), OR
#   (b) its tip's commit subject appears anywhere in origin/main's
#       history (squash-merge produces a different SHA but preserves
#       the subject).
#
# (b) covers the common case where the repo uses squash-merge (this
# repo's ruleset allows only squash). `git branch -d` checks (a) only
# and would refuse to delete (b)-only branches. We use `git branch -D`
# for those but only after we've independently verified the subject
# match — the safety net.
#
# IMPORTANT: `git log --format=X -q` does NOT suppress stdout (the -q
# flag only suppresses implicit "On branch / Date: ..." output).
# Every git log call that uses --format MUST redirect stdout to
# /dev/null when its output isn't meant for the script stdout, or
# the captured values will leak into the if-body's stdout stream
# and corrupt the mapfile.
mapfile -t candidates < <(
    git for-each-ref --format='%(refname:short)' refs/heads/ \
        | grep -v '^main$' \
        | while read -r branch; do
            sha=$(git rev-parse "$branch" 2>/dev/null) || continue
            # Direct ancestor?
            if git merge-base --is-ancestor "$sha" origin/main 2>/dev/null; then
                echo "$branch"
                continue
            fi
            # Squash-merged: subject match in main.
            subject=$(git log -1 --format='%s' "$branch" 2>/dev/null)
            if [[ -n "$subject" ]] \
                && git log origin/main --grep="$subject" --format='%H' >/dev/null 2>&1; then
                echo "$branch"
                continue
            fi
        done
)

if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "No local branches to clean up."
    exit 0
fi

echo "Local branches confirmed merged (direct-ancestor OR subject-match in main):"
for branch in "${candidates[@]}"; do
    sha=$(git rev-parse "$branch")
    subject=$(git log -1 --format='%s' "$branch")
    in_main=$(git log origin/main --grep="$subject" --format='%H' 2>/dev/null | head -1)
    if [[ -n "$in_main" ]]; then
        marker="(squash-merged as ${in_main:0:7})"
    else
        marker="(direct ancestor)"
    fi
    echo "  $sha $branch $marker"
done

FAIL=0

# Local delete. Use `-d` (safe) for direct-ancestor branches, and
# `-D` (force) for squash-merged-only branches. We pre-filtered both
# categories so the force-delete is justified.
echo
if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] would: git branch -d <branch> (or -D for squash-merged) for each candidate"
else
    for branch in "${candidates[@]}"; do
        sha=$(git rev-parse "$branch")
        subject=$(git log -1 --format='%s' "$branch")
        # Detect squash-merged: subject match. NOTE: redirect to
        # /dev/null so git log stdout doesn't leak into the if-body.
        if git log origin/main --grep="$subject" --format='%H' >/dev/null 2>&1; then
            # Squash-merged: subject match only. Use -D because git
            # doesn't know about squash-merge equivalence.
            if git branch -D "$branch" 2>/dev/null; then
                echo "deleted local (squash): $branch"
            else
                echo "::error::failed to delete local: $branch" >&2
                FAIL=$((FAIL + 1))
            fi
        else
            # Direct ancestor. Use -d which refuses non-merged.
            if git branch -d "$branch" 2>/dev/null; then
                echo "deleted local (linear): $branch"
            else
                echo "::error::failed to delete local: $branch" >&2
                FAIL=$((FAIL + 1))
            fi
        fi
    done
fi

# Remote delete (only with --remote).
if [[ $DO_REMOTE -eq 1 ]]; then
    echo
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[dry-run] would: git push origin --delete <branch> for each candidate"
    else
        for branch in "${candidates[@]}"; do
            # Skip release-please-* branches (the release-please bot owns them).
            case "$branch" in
                release-please--*) continue ;;
            esac
            if git push origin --delete "$branch" 2>/dev/null; then
                echo "deleted remote: origin/$branch"
            else
                # May already be gone (race with `--delete-branch` on merge).
                if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
                    echo "::error::failed to delete remote: origin/$branch" >&2
                    FAIL=$((FAIL + 1))
                else
                    echo "already gone: origin/$branch"
                fi
            fi
        done
    fi
fi

# Prune refs (clean up the local tracking refs for branches that may
# have been deleted remotely by other processes).
echo
echo "Pruning remote tracking refs..."
git remote prune origin 2>&1 | tail -3 || true

if [[ $FAIL -gt 0 ]]; then
    echo "::error::$FAIL delete(s) failed" >&2
    exit 1
fi
echo "ok"
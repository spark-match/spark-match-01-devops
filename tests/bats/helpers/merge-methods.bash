# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# helpers/merge-methods.bash - bats helpers for configure-merge-methods.sh
# =============================================================================
# Provides a `gh` stub that routes to fake responses and logs every call so
# tests can assert on call presence, ordering, and flags used.
#
# Fixture markers (in $BATS_TEST_TMPDIR):
#   list-fail       forces the orgs/<org>/repos listing to exit non-zero
#   patch-fail      forces every repos/<owner>/<repo> PATCH to exit non-zero
#   repos-empty     returns an empty repo list (tests no-work path)
# =============================================================================

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/configure-merge-methods.sh"

gh() {
  echo "gh $*" >> "$BATS_TEST_TMPDIR/gh.log"

  case "${1:-}" in
    auth)
      # gh auth status -> exit 0 (script prereq check passes).
      return 0
      ;;

    api)
      shift
      local method="GET"
      local url=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -X)        method="$2"; shift 2 ;;
          --method)  method="$2"; shift 2 ;;
          -F|-f|-H|--jq|--input|--hostname|--template|--cache|--preview)
            shift 2
            ;;
          -*)
            shift 1
            ;;
          *)
            if [[ -z "$url" ]]; then
              url="${1#/}"
              shift 1
            else
              shift 1
            fi
            ;;
        esac
      done

      [[ -t 0 ]] || cat >/dev/null 2>&1 || true

      # --- Marker-driven failures ------------------------------------------
      if [[ -f "$BATS_TEST_TMPDIR/list-fail" ]] \
         && [[ "$url" =~ ^orgs/[^/]+/repos$ ]]; then
        echo "ERROR: fake listing failure" >&2
        return 1
      fi

      if [[ -f "$BATS_TEST_TMPDIR/patch-fail" ]] \
         && [[ "$method" == "PATCH" ]] \
         && [[ "$url" =~ ^repos/[^/]+/[^/]+$ ]]; then
        echo "ERROR: fake PATCH failure" >&2
        return 1
      fi

      # --- Dispatch on URL + method ----------------------------------------

      # GET orgs/<org>/repos (with --paginate) -> list of full_names.
      if [[ "$url" =~ ^orgs/[^/]+/repos$ ]]; then
        if [[ -f "$BATS_TEST_TMPDIR/repos-empty" ]]; then
          return 0
        fi
        printf '%s\n' \
          "spark-match/spark-match-foo" \
          "spark-match/spark-match-bar"
        return 0
      fi

      # PATCH repos/<owner>/<repo> -> formatted result.
      if [[ "$method" == "PATCH" ]] && [[ "$url" =~ ^repos/[^/]+/[^/]+$ ]]; then
        echo "s=true m=true r=true d=true"
        return 0
      fi

      # GET repos/<owner>/<repo> (dry-run path).
      if [[ "$url" =~ ^repos/[^/]+/[^/]+$ ]]; then
        echo '{"allow_squash_merge":true,"allow_merge_commit":true,"allow_rebase_merge":true,"delete_branch_on_merge":false}'
        return 0
      fi

      # Fallback: empty 200 (don't crash on un-stubbed URLs).
      echo "{}"
      return 0
      ;;

    *)
      return 0
      ;;
  esac
}
export -f gh
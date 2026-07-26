# =============================================================================
# helpers/reconciler.bash - bats helpers for configure-repo-rulesets.sh tests
# =============================================================================
# Loads bats-support / bats-assert if present (best-effort).
# Defines a `gh` stub that routes `gh api` calls to fixture files, so the
# reconciler script can be exercised end-to-end without hitting GitHub.
#
# Fixture layout (relative to $BATS_TEST_TMPDIR/fixtures/):
#   team-<slug>               JSON {"id": 12345} or {"id": null} for not-found
#   rulesets-list.json        JSON array of rulesets (GET /rulesets response)
#   rule-<id>.json            JSON of single ruleset (GET /rulesets/<id>)
#   put-rejected              presence forces PUT to exit non-zero
#   post-rejected             presence forces POST to exit non-zero
#
# All `gh` invocations are logged to $BATS_TEST_TMPDIR/gh.log so tests can
# assert on call count + ordering (PUT/POST presence/absence).
# =============================================================================

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/configure-repo-rulesets.sh"

# bats-support / bats-assert (best-effort load, no-op if not present)
load_bats_helpers() {
  for lib in "$BATS_LIBPATH/bats-support/load.bash" \
             "$HOME/.local/share/bats/bats-support/load.bash"; do
    if [[ -f "$lib" ]]; then
      # shellcheck source=/dev/null
      source "$lib"
      break
    fi
  done
  for lib in "$BATS_LIBPATH/bats-assert/load.bash" \
             "$HOME/.local/share/bats/bats-assert/load.bash"; do
    if [[ -f "$lib" ]]; then
      # shellcheck source=/dev/null
      source "$lib"
      break
    fi
  done
}
load_bats_helpers

# --- Default manifest (tests override per-case) ----------------------------
DEFAULT_MANIFEST='{
  "version": 2,
  "defaults": {
    "approvals": 1,
    "dismissStaleReviews": true,
    "requireConversationResolution": true,
    "requireLastPushApproval": false,
    "requireCodeOwnerReview": true,
    "allowedMergeMethods": ["squash"],
    "adminBypassMode": "pull_request",
    "blockDeletion": true,
    "blockForcePush": true,
    "requireLinearHistory": true,
    "rulesetName": "spark-match-default-branch-protection",
    "rulesetTarget": "branch",
    "rulesetEnforcement": "active"
  },
  "repositories": {
    "spark-match-foo": {
      "refs": ["~DEFAULT_BRANCH"],
      "reviewerTeam": "devops",
      "filePatterns": ["**"],
      "statusChecks": ["ci / ci"]
    },
    "spark-match-bar": {
      "refs": ["~DEFAULT_BRANCH", "refs/heads/dev"],
      "reviewerTeam": "devops",
      "filePatterns": ["**"],
      "statusChecks": []
    }
  }
}'

# Write the default manifest into the test's tmp dir under fixtures/.
write_default_manifest() {
  mkdir -p "$BATS_TEST_TMPDIR/fixtures"
  echo "$DEFAULT_MANIFEST" > "$BATS_TEST_TMPDIR/fixtures/manifest.json"
}

# gh stub: overrides the real `gh` binary for the duration of the test.
# Logs every call; routes `gh api` to fixture files.
# -----------------------------------------------------------------------------
# bats-facing helper: json_output
# -----------------------------------------------------------------------------
# bats 1.x `run` merges stdout and stderr into $output. To assert on the
# script's JSON output we must strip the script's [INFO]/[WARN]/[ERR] log
# lines (which go to stderr) and any leading blank line the script emits
# before the JSON block.
#
# Usage in a test:
#   output_json=$(json_output)
#   echo "$output_json" | jq -e '.[] | .state == "..."' >/dev/null
# -----------------------------------------------------------------------------
json_output() {
  printf '%s\n' "$output" \
    | grep -v '^\[INFO\]' \
    | grep -v '^\[WARN\]' \
    | grep -v '^\[ERR' \
    | sed '1{/^$/d}'
}
export -f json_output

# -----------------------------------------------------------------------------
# gh stub: overrides the real `gh` binary for the duration of the test.
# Logs every call; routes `gh api` to fixture files.
# -----------------------------------------------------------------------------
gh() {
  echo "gh $*" >> "$BATS_TEST_TMPDIR/gh.log"

  case "${1:-}" in
    auth)
      # `gh auth status` -> success so the script proceeds past prereq check.
      # `gh auth token`   -> echo a fake token (never asserted; just presence).
      case "${2:-}" in
        status) return 0 ;;
        token)  echo "fake-token-for-test" ;;
        *)      return 0 ;;
      esac
      ;;

    api)
      # Collect args. URL is positional after `api`; flags are interspersed.
      shift
      local method="GET"
      local url=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -X) method="$2"; shift 2 ;;
          -H|-F|--input|--jq|--cache|-f|-d|--data|--hostname|--include|--method)
            # Consume flag + (optional) value.
            shift 2
            ;;
          -*)
            shift
            ;;
          *)
            # First non-flag positional is the URL.
            if [[ -z "$url" ]]; then
              url="${1#/}"
              shift
            else
              shift
            fi
            ;;
        esac
      done

      # Strip stdin consumed by `--input -` (script pipes JSON into PUT/POST).
      [[ -t 0 ]] || cat >/dev/null 2>&1 || true

      # --- Dispatch on URL pattern + method -------------------------------
      local fx="$BATS_TEST_TMPDIR/fixtures"

      # PUT / POST to a single ruleset: gate on reject fixtures.
      if [[ "$method" == "PUT" && "$url" =~ ^repos/[^/]+/[^/]+/rulesets/([^/]+)$ ]]; then
        if [[ -f "$fx/put-rejected" ]]; then return 1; fi
        echo '{"id":99}'
        return 0
      fi
      if [[ "$method" == "POST" && "$url" =~ ^repos/[^/]+/[^/]+/rulesets$ ]]; then
        if [[ -f "$fx/post-rejected" ]]; then return 1; fi
        echo '{"id":99}'
        return 0
      fi

      # GET orgs/<org>/teams/<slug>  (team_id resolution)
      if [[ "$url" =~ ^orgs/[^/]+/teams/(.+)$ ]]; then
        local slug="${BASH_REMATCH[1]}"
        if [[ -f "$fx/team-$slug" ]]; then
          jq -r '.id // empty' "$fx/team-$slug"
          return 0
        fi
        # Not found: emit empty + non-zero (script falls back to "" or errors).
        return 1
      fi

      # GET repos/<owner>/<repo>/rulesets/<id>  (single ruleset)
      if [[ "$url" =~ ^repos/[^/]+/[^/]+/rulesets/([^/]+)$ ]]; then
        local id="${BASH_REMATCH[1]}"
        if [[ -f "$fx/rule-$id.json" ]]; then
          cat "$fx/rule-$id.json"
          return 0
        fi
        echo "{}"
        return 0
      fi

      # GET repos/<owner>/<repo>/rulesets  (list)
      if [[ "$url" =~ ^repos/[^/]+/[^/]+/rulesets$ ]]; then
        if [[ -f "$fx/rulesets-list.json" ]]; then
          cat "$fx/rulesets-list.json"
          return 0
        fi
        echo "[]"
        return 0
      fi

      # Fallback: empty 200 (so the script does not crash on un-stubbed URLs).
      echo "{}"
      return 0
      ;;

    *)
      # Pass through anything else (e.g. `gh --version`, `gh repo view`).
      return 0
      ;;
  esac
}
export -f gh

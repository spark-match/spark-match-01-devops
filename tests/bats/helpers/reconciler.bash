# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# helpers/reconciler.bash - bats helpers for configure-repo-rulesets.sh tests
# =============================================================================
# Defines a `gh` stub that routes `gh api` calls to fixture files, so the
# reconciler script can be exercised end-to-end without hitting GitHub.
#
# Fixture layout (relative to $BATS_TEST_TMPDIR/fixtures/):
#   team-<slug>               JSON {"id": 12345} or {"id": null} for not-found
#   rulesets-list.json        JSON array of rulesets (GET /rulesets response)
#   rule-<id>.json            JSON of single ruleset (GET /rulesets/<id>)
#   put-rejected              presence forces PUT to exit non-zero
#   post-rejected             presence forces POST to exit non-zero
#   backup-fail               presence forces the 2nd+ GET to rulesets/<id>
#                              to exit non-zero (used to test backup-failure-
#                              blocks-PUT; first GET is the script's
#                              fetch_current_ruleset, second is the backup)
#
# All `gh` invocations are logged to $BATS_TEST_TMPDIR/gh.log so tests can
# assert on call count + ordering (PUT/POST presence/absence).
# =============================================================================

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/configure-repo-rulesets.sh"
MANIFEST="$REPO_ROOT/governance/repository-governance.json"

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

      # DELETE repos/<owner>/<repo>/rulesets/<id>  (used by --prune-unexpected).
      # Default: success (no output). Markers to opt into failure modes:
      #   delete-rejected      -> exit non-zero (delete fails)
      if [[ "$method" == "DELETE" && "$url" =~ ^repos/[^/]+/[^/]+/rulesets/([^/]+)$ ]]; then
        if [[ -f "$fx/delete-rejected" ]]; then return 1; fi
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
        if [[ -f "$fx/backup-fail" ]]; then
          # 1ra llamada = fetch_current_ruleset (debe OK).
          # 2da+        = backup_ruleset        (debe fallar).
          local cnt_file="$fx/_get-count"
          local cnt
          cnt=$(cat "$cnt_file" 2>/dev/null || echo 0)
          cnt=$((cnt + 1))
          echo "$cnt" > "$cnt_file"
          if [[ "$cnt" -gt 1 ]]; then
            echo "fake backup failure for ruleset $id" >&2
            return 1
          fi
        fi
        if [[ -f "$fx/rule-$id.json" ]]; then
          cat "$fx/rule-$id.json"
          return 0
        fi
        echo "{}"
        return 0
      fi

      # GET repos/<owner>/<repo>/branches?protected=true...  (ramas candidatas)
      #
      # El script la llama con --paginate --jq '.[].name', y este stub descarta
      # los flags, asi que hay que emitir ya los nombres filtrados, uno por
      # linea, igual que se hace con default-branch. Marker:
      #   protected-branches         -> un nombre de rama por linea
      # Sin fixture devuelve vacio: el script cae en la union con la rama por
      # defecto y las refs del manifiesto, que es justo lo que hay que probar.
      if [[ "$url" =~ ^repos/[^/]+/[^/]+/branches\? ]]; then
        if [[ -f "$fx/protected-branches" ]]; then
          cat "$fx/protected-branches"
        fi
        return 0
      fi

      # repos/<owner>/<repo>/branches/<branch>/protection  (branch protection
      # CLASICA, la superficie legacy que convive con los rulesets).
      #
      # Sin fixture devuelve no-cero, que es lo que hace la API real con 404 y
      # es el estado deseado: no hay proteccion clasica. Markers:
      #   legacy-protection-<rama>.json  -> esa rama concreta la tiene
      #   legacy-protection.json         -> SOLO la rama por defecto la tiene
      #   legacy-delete-rejected         -> el DELETE falla
      #
      # Que legacy-protection.json aplique unicamente a la rama por defecto es
      # deliberado: antes el stub lo devolvia para cualquier rama, y desde que
      # el script barre todas las ramas eso convertiria cada fixture en varios
      # hallazgos. Los tests que solo quieren "este repo tiene proteccion
      # clasica" siguen escribiendo el fichero de siempre.
      # La rama va sin escapar y puede llevar barras (release/1.x, feat/x), que
      # es lo que acepta la API real, asi que el patron tiene que ser .+ y no
      # [^/]+. Con [^/]+ una rama con barra no casaba aqui, se colaba hasta el
      # fallback de "200 vacio" y el script la leia como protegida.
      if [[ "$url" =~ ^repos/[^/]+/[^/]+/branches/(.+)/protection$ ]]; then
        local br="${BASH_REMATCH[1]}"
        if [[ "$method" == "DELETE" ]]; then
          if [[ -f "$fx/legacy-delete-rejected" ]]; then return 1; fi
          return 0
        fi
        # legacy-backup-fail: la 1ra GET de cada rama (la deteccion) va bien y
        # la 2da (el respaldo previo al DELETE) falla. Sirve para comprobar que
        # sin respaldo no se borra.
        if [[ -f "$fx/legacy-backup-fail" ]]; then
          local safe="${br//\//-}"
          local cnt_file="$fx/_legacy-get-count-$safe"
          local cnt
          cnt=$(cat "$cnt_file" 2>/dev/null || echo 0)
          cnt=$((cnt + 1))
          echo "$cnt" > "$cnt_file"
          if [[ "$cnt" -gt 1 ]]; then
            echo "fake backup failure for $br" >&2
            return 1
          fi
        fi
        if [[ -f "$fx/legacy-protection-$br.json" ]]; then
          cat "$fx/legacy-protection-$br.json"
          return 0
        fi
        local default_br
        default_br=$(cat "$fx/default-branch" 2>/dev/null || echo "main")
        if [[ -f "$fx/legacy-protection.json" && "$br" == "$default_br" ]]; then
          cat "$fx/legacy-protection.json"
          return 0
        fi
        return 1
      fi

      # GET repos/<owner>/<repo>  (resolucion de default_branch).
      # El script la llama con --jq '.default_branch', y este stub descarta los
      # flags, asi que hay que emitir ya el valor filtrado, no el objeto.
      if [[ "$url" =~ ^repos/[^/]+/[^/]+$ ]]; then
        if [[ -f "$fx/default-branch" ]]; then
          cat "$fx/default-branch"
        else
          echo "main"
        fi
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

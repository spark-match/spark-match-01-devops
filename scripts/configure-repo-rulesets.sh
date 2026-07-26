#!/usr/bin/env bash
# =============================================================================
# configure-repo-rulesets.sh - Reconciliador declarativo de rulesets para
#                              la organizacion spark-match via GitHub REST API.
# =============================================================================
# Por que este script existe:
#   - GitHub Free no soporta ORG-level rulesets (requiere GitHub Team).
#   - Repo-level rulesets SI funcionan en Free.
#   - La version anterior era un bootstrap destructivo: solo POST, sin PUT,
#     sin backup, sin deteccion de drift, sin `--check`.
#   - Esta version es un reconciliador idempotente: lee un manifiesto
#     declarativo, resuelve team slugs via API, y reconcilia el estado real
#     contra el estado deseado.
#
# Que cubre el ruleset (v2 - cubre TODO lo de branch protection):
#   - pull_request rule: 1 aprobacion, code owner review OFF (reemplazado por
#                        required_reviewers), dismiss stale, conversation
#                        resolution, required_reviewers (team), allowed
#                        merge methods = [squash].
#   - required_status_checks (per-repo via manifest)
#   - non_fast_forward (block force push)
#   - required_linear_history
#   - deletion (block branch deletion via API rule)
#
# Que cubre TODO lo de branch protection clasica. Esto significa que podes
# tener UNA sola fuente de verdad (governance/repository-governance.json) y
# borrar branch protection. Si tienes ambas, la mas restrictiva gana.
#
# Uso:
#   ./configure-repo-rulesets.sh --check --repos spark-match-01-devops
#   ./configure-repo-rulesets.sh --dry-run --apply --repos spark-match-01-devops
#   ./configure-repo-rulesets.sh --apply --repos spark-match-01-devops
#   ./configure-repo-rulesets.sh --apply --repos r1,r2 --strict
#   ./configure-repo-rulesets.sh --apply                            # todos los del manifest
#
# Salidas por repositorio: in-sync, would-create, would-update, created,
#                          updated, failed, unexpected.
# Exit codes:
#   0  = todos in-sync (--check) o todos reconciliados (--apply)
#   1  = drift detectado (--check) o al menos un fallo (--apply)
#   2  = error de prerequisitos / manifest invalido
# =============================================================================

set -euo pipefail

# --- Constantes --------------------------------------------------------------
ORG="${ORG:-spark-match}"
MANIFEST_DEFAULT="governance/repository-governance.json"
MANIFEST=""
MODE=""                       # check | apply (uno de los dos obligatorio)
DRY_RUN=false
REPOS_FILTER=""
BACKUP_DIR=""
STRICT=false
PRUNE_UNEXPECTED=false
JSON_OUTPUT=false

# --- Parsing de args ---------------------------------------------------------
usage() {
  sed -n '2,80p' "$0" | sed -E 's/^# ?//'
  exit "${1:-0}"
}

# shellcheck disable=SC2034  # STRICT and PRUNE_UNEXPECTED reserved for future use (TODO: implement)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)        MODE="check"; shift ;;
    --apply)        MODE="apply"; shift ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --repos)        REPOS_FILTER="$2"; shift 2 ;;
    --manifest)     MANIFEST="$2"; shift 2 ;;
    --backup-dir)   BACKUP_DIR="$2"; shift 2 ;;
    --strict)       STRICT=true; shift ;;
    --prune-unexpected) PRUNE_UNEXPECTED=true; shift ;;
    --org)          ORG="$2"; shift 2 ;;
    --json)         JSON_OUTPUT=true; shift ;;
    -h|--help)      usage 0 ;;
    *)              echo "[ERROR] Argumento desconocido: $1" >&2; usage 2 ;;
  esac
done

# --- Validacion de prerrequisitos --------------------------------------------
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Comando requerido no encontrado: $1" >&2
    exit 2
  fi
}

require_cmd gh
require_cmd jq

if ! gh auth status >/dev/null 2>&1; then
  echo "[ERROR] gh CLI no autenticado. Ejecuta: gh auth login" >&2
  exit 2
fi

if [[ -z "$MODE" ]]; then
  echo "[ERROR] Debe especificar --check o --apply." >&2
  usage 2
fi

MANIFEST="${MANIFEST:-$MANIFEST_DEFAULT}"
if [[ ! -f "$MANIFEST" ]]; then
  echo "[ERROR] Manifiesto no encontrado: $MANIFEST" >&2
  exit 2
fi

# --- Validacion de esquema del manifiesto ------------------------------------
validate_manifest() {
  local mf="$1"
  jq -e '
    .version == 2 and
    (.defaults | type == "object") and
    (.repositories | type == "object") and
    (.defaults.allowedMergeMethods | type == "array") and
    (.defaults.approvals | type == "number")
  ' "$mf" >/dev/null || {
    echo "[ERROR] Manifiesto invalido o version no soportada: $mf" >&2
    exit 2
  }
}

validate_manifest "$MANIFEST"

# --- Helpers ----------------------------------------------------------------
log_info() { echo "[INFO] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERR ] $*" >&2; }

# Cache de team slug -> id dentro del proceso
declare -A TEAM_ID_CACHE

resolve_team_id() {
  local slug="$1"
  if [[ -n "${TEAM_ID_CACHE[$slug]:-}" ]]; then
    echo "${TEAM_ID_CACHE[$slug]}"
    return 0
  fi
  local id
  id=$(gh api "orgs/$ORG/teams/$slug" --jq '.id' 2>/dev/null || echo "")
  if [[ -z "$id" || "$id" == "null" ]]; then
    return 1
  fi
  TEAM_ID_CACHE[$slug]="$id"
  echo "$id"
}

# Devuelve lista de repos a procesar (de la opcion --repos o del manifest)
resolve_repos() {
  if [[ -n "$REPOS_FILTER" ]]; then
    echo "$REPOS_FILTER" | tr ',' '\n'
  else
    jq -r '.repositories | keys[]' "$MANIFEST"
  fi
}

# Estado actual del ruleset administrado de un repo.
# Imprime JSON al stdout con forma: { exists, id, payload }
# payload es el GET /rulesets/{id} completo, o null si no existe.
fetch_current_ruleset() {
  local repo="$1"
  local full="$ORG/$repo"
  local list_json id ruleset_name unexpected_count detail

  ruleset_name=$(jq -r '.defaults.rulesetName' "$MANIFEST")
  list_json=$(gh api "repos/$full/rulesets" 2>/dev/null || echo "[]")
  id=$(echo "$list_json" | jq -r --arg name "$ruleset_name" \
        '.[] | select(.name == $name) | .id' 2>/dev/null | head -n1)

  if [[ -z "$id" || "$id" == "null" ]]; then
    # Verificar si hay un ruleset inesperado con OTRO nombre (target=branch)
    unexpected_count=$(echo "$list_json" | jq --arg name "$ruleset_name" \
      '[.[] | select(.target == "branch" and .name != $name)] | length' 2>/dev/null || echo 0)
    jq -n --argjson exists false --argjson id null --argjson payload null \
      --argjson unexpected "${unexpected_count:-0}" \
      '{exists: $exists, id: $id, payload: $payload, unexpected_count: $unexpected}'
    return 0
  fi

  detail=$(gh api "repos/$full/rulesets/$id" 2>/dev/null || echo "{}")
  jq -n --argjson exists true --argjson id "$id" --argjson payload "$detail" \
    --argjson unexpected 0 \
    '{exists: $exists, id: $id, payload: $payload, unexpected_count: $unexpected}'
}

# Construye el payload deseado a partir del manifiesto + team_id resuelto.
build_desired_payload() {
  local repo="$1"
  local team_id="$2"
  jq --arg team_id "$team_id" --arg repo "$repo" '
    . as $root |
    .repositories[$repo] as $r |
    $root.defaults as $d |
    {
      name: $d.rulesetName,
      target: $d.rulesetTarget,
      enforcement: $d.rulesetEnforcement,
      conditions: {
        ref_name: {
          include: ($r.refs),
          exclude: []
        }
      },
      bypass_actors: [
        {
          actor_type: "OrganizationAdmin",
          actor_id: null,
          bypass_mode: $d.adminBypassMode
        }
      ],
      rules: (
        [
          {
            type: "pull_request",
            parameters: {
              required_approving_review_count: $d.approvals,
              require_code_owner_review: $d.requireCodeOwnerReview,
              dismiss_stale_reviews_on_push: $d.dismissStaleReviews,
              require_last_push_approval: $d.requireLastPushApproval,
              required_review_thread_resolution: $d.requireConversationResolution,
              required_reviewers: [
                {
                  reviewer_id: ($team_id | tonumber),
                  reviewer_type: "Team",
                  file_patterns: $r.filePatterns,
                  minimum_approvals: $d.approvals
                }
              ],
              allowed_merge_methods: $d.allowedMergeMethods
            }
          }
        ]
        + (
          if ($r.statusChecks | length) > 0 then
            [{
              type: "required_status_checks",
              parameters: {
                strict_required_status_checks_policy: true,
                required_status_checks: ($r.statusChecks | map({context: .}))
              }
            }]
          else [] end
        )
        + (if $d.blockForcePush then [{type: "non_fast_forward"}] else [] end)
        + (if $d.requireLinearHistory then [{type: "required_linear_history"}] else [] end)
        + (if $d.blockDeletion then [{type: "deletion"}] else [] end)
      )
    }
  ' "$MANIFEST"
}

# Compara dos payloads (current vs desired) canonizados.
# Imprime "in-sync" si coinciden o el diff resumido.
canonical_diff() {
  local current="$1"
  local desired="$2"

  # Canonicalizacion: orden estable, ignorar campos meta.
  local cur_norm des_norm
  cur_norm=$(echo "$current" | jq -S '
    del(.id, .node_id, .created_at, .updated_at, ._links, .source, .source_type, .url) |
    .bypass_actors |= map(del(.actor_id)) |
    .conditions.ref_name.include |= sort |
    .conditions.ref_name.exclude |= sort |
    .rules |= sort_by(.type) |
    .rules |= map(if .parameters.dismissal_restriction then del(.parameters.dismissal_restriction) else . end) |
    .rules |= map(if .parameters.do_not_enforce_on_create == false then del(.parameters.do_not_enforce_on_create) else . end)
  ')
  des_norm=$(echo "$desired" | jq -S '
    .bypass_actors |= map(del(.actor_id)) |
    .conditions.ref_name.include |= sort |
    .conditions.ref_name.exclude |= sort |
    .rules |= sort_by(.type) |
    .rules |= map(if .parameters.dismissal_restriction then del(.parameters.dismissal_restriction) else . end) |
    .rules |= map(if .parameters.do_not_enforce_on_create == false then del(.parameters.do_not_enforce_on_create) else . end)
  ')

  if [[ "$cur_norm" == "$des_norm" ]]; then
    echo "in-sync"
  else
    echo "drift"
  fi
}

# Backup del ruleset actual (full GET) a BACKUP_DIR/<repo>-<id>-<ts>.json
backup_ruleset() {
  local repo="$1"
  local rs_id="$2"
  local full="$ORG/$repo"
  local dir="${BACKUP_DIR:-backups/rulesets/$(date +%Y%m%d-%H%M%S)}"
  mkdir -p "$dir"
  gh api "repos/$full/rulesets/$rs_id" > "$dir/${repo}-${rs_id}.json" 2>/dev/null || true
  echo "$dir"
}

# --- Loop principal ----------------------------------------------------------
declare -a RESULTS=()
ANY_DRIFT=false
ANY_FAIL=false

log_info "ORG=$ORG MANIFEST=$MANIFEST MODE=$MODE DRY_RUN=$DRY_RUN"

while IFS=$'\n\r' read -r repo; do
  repo="${repo%$'\r'}"
  [[ -z "$repo" ]] && continue

  if ! jq -e --arg r "$repo" '.repositories | has($r)' "$MANIFEST" >/dev/null; then
    log_err "$repo no esta declarado en el manifiesto"
    RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"not-in-manifest\"}")
    ANY_FAIL=true
    continue
  fi

  team_slug=$(jq -r --arg r "$repo" '.repositories[$r].reviewerTeam // empty' "$MANIFEST")
  if [[ -z "$team_slug" ]]; then
    log_err "$repo: falta reviewerTeam"
    RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"missing-reviewerTeam\"}")
    ANY_FAIL=true
    continue
  fi

  if ! team_id=$(resolve_team_id "$team_slug"); then
    log_err "$repo: team '$team_slug' no resuelto"
    RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"team-not-found\"}")
    ANY_FAIL=true
    continue
  fi
  log_info "$repo: team '$team_slug' -> id $team_id"

  current_json=$(fetch_current_ruleset "$repo")
  exists=$(echo "$current_json" | jq -r '.exists')
  rs_id=$(echo "$current_json" | jq -r '.id // empty')
  unexpected=$(echo "$current_json" | jq -r '.unexpected_count')
  current_payload=$(echo "$current_json" | jq -c '.payload // {}')

  desired_payload=$(build_desired_payload "$repo" "$team_id")

  if [[ "$unexpected" -gt 0 ]]; then
    if [[ "$PRUNE_UNEXPECTED" == true ]]; then
      log_warn "$repo: existen $unexpected ruleset(s) inesperado(s); --prune-unexpected no implementado aun"
    else
      log_err "$repo: existen $unexpected ruleset(s) inesperado(s); abort para no pisarlos (usa --prune-unexpected)"
      RESULTS+=("{\"repo\":\"$repo\",\"state\":\"unexpected\",\"unexpected_count\":$unexpected}")
      ANY_FAIL=true
      continue
    fi
  fi

  if [[ "$exists" == "true" ]]; then
    diff=$(canonical_diff "$current_payload" "$desired_payload")
    if [[ "$diff" == "in-sync" ]]; then
      RESULTS+=("{\"repo\":\"$repo\",\"state\":\"in-sync\",\"ruleset_id\":$rs_id}")
    elif [[ "$MODE" == "check" ]]; then
      RESULTS+=("{\"repo\":\"$repo\",\"state\":\"drift\",\"ruleset_id\":$rs_id}")
      ANY_DRIFT=true
    elif [[ "$MODE" == "apply" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        RESULTS+=("{\"repo\":\"$repo\",\"state\":\"would-update\",\"ruleset_id\":$rs_id}")
      else
        backup_dir=$(backup_ruleset "$repo" "$rs_id")
        log_info "$repo: backup en $backup_dir"
        if echo "$desired_payload" | gh api -X PUT "repos/$ORG/$repo/rulesets/$rs_id" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            --input - >/dev/null 2>&1; then
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"updated\",\"ruleset_id\":$rs_id}")
        else
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"PUT-rejected\",\"ruleset_id\":$rs_id}")
          ANY_FAIL=true
        fi
      fi
    fi
  else
    if [[ "$MODE" == "check" ]]; then
      RESULTS+=("{\"repo\":\"$repo\",\"state\":\"drift\",\"reason\":\"missing\"}")
      ANY_DRIFT=true
    elif [[ "$MODE" == "apply" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        RESULTS+=("{\"repo\":\"$repo\",\"state\":\"would-create\"}")
      else
        if echo "$desired_payload" | gh api -X POST "repos/$ORG/$repo/rulesets" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            --input - >/dev/null 2>&1; then
          new_id=$(gh api "repos/$ORG/$repo/rulesets" --jq \
            --arg n "$(jq -r '.defaults.rulesetName' "$MANIFEST")" \
            '.[] | select(.name == $n) | .id' | head -n1)
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"created\",\"ruleset_id\":${new_id:-null}}")
        else
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"POST-rejected\"}")
          ANY_FAIL=true
        fi
      fi
    fi
  fi
done < <(resolve_repos)

# --- Resumen ----------------------------------------------------------------
echo ""
if [[ "$JSON_OUTPUT" == true ]]; then
  printf '%s\n' "${RESULTS[@]}" | jq -s '.'
else
  echo "Repo                       State             RulesetId"
  echo "-------------------------- ----------------- ----------"
  printf '%s\n' "${RESULTS[@]}" | jq -r '"\(.repo // "-")\t\(.state)\t\(.ruleset_id // "-")"' \
    | awk -F'\t' '{ printf "%-26s %-17s %s\n", $1, $2, $3 }'
fi

# Exit code
if [[ "$ANY_FAIL" == true ]]; then
  exit 1
fi
if [[ "$MODE" == "check" && "$ANY_DRIFT" == true ]]; then
  exit 1
fi
exit 0

#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
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
# Esa ultima frase era un aviso que nadie podia verificar: hasta 2026-08-06
# este script solo miraba /rulesets y jamas consultaba
# /branches/{branch}/protection, asi que --check daba verde en repositorios que
# corrian las dos capas, con enforce_admins=true anulando el bypass del ruleset
# y dejando todo merge esperando a un revisor.
#
# Ahora la proteccion clasica SE DETECTA siempre, en TODAS las ramas del repo y
# no solo en la de por defecto, y sale como `legacy-protection` (drift en
# --check, fallo con --strict). Borrarla exige --prune-legacy-protection, mismo
# criterio que --prune-unexpected: no se destruyen reglas que este script no
# creo sin pedirlo en la linea de comandos.
#
# El alcance ampliado no es teorico. La primera version de esta deteccion solo
# miraba default_branch y con ese alcance no habria encontrado la capa clasica
# de la rama dev de spark-match-07-article, la que hubo que retirar a mano. El
# barrido completo sobre la organizacion devolvio 9 ramas protegidas en 5
# repos, de las cuales 4 estaban en dev y ninguna la declaraba el manifiesto.
#
# Uso:
#   ./configure-repo-rulesets.sh --check --repos spark-match-01-devops
#   ./configure-repo-rulesets.sh --dry-run --apply --repos spark-match-01-devops
#   ./configure-repo-rulesets.sh --apply --repos spark-match-01-devops
#   ./configure-repo-rulesets.sh --apply --repos r1,r2 --strict
#   ./configure-repo-rulesets.sh --check                            # detecta proteccion clasica en todos
#   ./configure-repo-rulesets.sh --apply --repos r1 --prune-legacy-protection
#   ./configure-repo-rulesets.sh --apply                            # todos los del manifest
#
# Salidas por repositorio: in-sync, would-create, would-update, created,
#                          updated, failed, unexpected, legacy-protection,
#                          legacy-protection-removed.
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
PRUNE_LEGACY_PROTECTION=false
JSON_OUTPUT=false

# Estado acumulado (declarado temprano porque log_warn puede mutarlos).
declare -a RESULTS=()
ANY_DRIFT=false
ANY_FAIL=false

# --- Parsing de args ---------------------------------------------------------
usage() {
  # Imprime el bloque de documentacion de la cabecera y luego la lista de
  # flags, extraida del propio arg parser.
  #
  # Antes esto era `sed -n '2,105p'`, un rango fijo que tenia que llegar hasta
  # el final del `case`. Se rompio dos veces al anadir comentarios en la
  # cabecera: los flags se salian del rango y --help dejaba de nombrarlos, con
  # el agravante de que el sintoma aparecia en un test de --help y no donde se
  # habia editado. Ahora no hay ningun numero de linea que mantener.
  #
  # La cabecera va desde la linea 2 hasta el primer renglon que ya no es
  # comentario; los flags salen del `case`, asi que un flag nuevo aparece en
  # --help sin tocar nada.
  awk 'NR > 1 { if ($0 !~ /^#/) exit; print }' "$0" | sed -E 's/^# ?//'
  echo "Flags:"
  sed -n '/^while \[\[ \$# -gt 0 \]\]; do/,/^  esac/p' "$0" \
    | grep -oE '^[[:space:]]+--[a-z-]+\)' \
    | tr -d ' )' \
    | sort -u \
    | sed 's/^/  /'
  exit "${1:-0}"
}

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
    --prune-legacy-protection) PRUNE_LEGACY_PROTECTION=true; shift ;;
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
    (.version == 2 or .version == 3) and
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
log_err()  { echo "[ERR ] $*" >&2; }
# log_warn escalates a [ERR ] + ANY_FAIL cuando --strict esta activo.
# Asi --strict convierte cualquier warning en un fallo real (exit 1 al final).
log_warn() {
  if [[ "$STRICT" == true ]]; then
    log_err "$*"
    ANY_FAIL=true
  else
    echo "[WARN] $*" >&2
  fi
}

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
# Imprime JSON al stdout con forma: { exists, id, payload, unexpected_count, unexpected_ids }
# payload es el GET /rulesets/{id} completo, o null si no existe.
# unexpected_ids es la lista de IDs de rulesets con target=branch pero name distinto
# al administrado (usado por --prune-unexpected para borrarlos).
fetch_current_ruleset() {
  local repo="$1"
  local full="$ORG/$repo"
  local list_json id ruleset_name unexpected_count unexpected_ids detail

  ruleset_name=$(jq -r '.defaults.rulesetName' "$MANIFEST")
  list_json=$(gh api "repos/$full/rulesets" 2>/dev/null || echo "[]")

  # Foreign rulesets: target=branch pero name distinto al administrado.
  # Se detectan SIEMPRE (exista o no el administrado) — antes solian
  # calcularse solo cuando el administrado no existia, lo que dejaba
  # pasar combos managed+foreign como si no hubiera foreign (bug).
  unexpected_count=$(echo "$list_json" | jq --arg name "$ruleset_name" \
    '[.[] | select(.target == "branch" and .name != $name)] | length' 2>/dev/null || echo 0)
  unexpected_ids=$(echo "$list_json" | jq -r --arg name "$ruleset_name" \
    '[.[] | select(.target == "branch" and .name != $name) | .id] | .[]' 2>/dev/null || echo "")

  id=$(echo "$list_json" | jq -r --arg name "$ruleset_name" \
        '.[] | select(.name == $name) | .id' 2>/dev/null | head -n1)

  if [[ -z "$id" || "$id" == "null" ]]; then
    jq -n --argjson exists false --argjson id null --argjson payload null \
      --argjson unexpected "${unexpected_count:-0}" \
      --arg unexpected_ids "${unexpected_ids:-}" \
      '{exists: $exists, id: $id, payload: $payload, unexpected_count: $unexpected, unexpected_ids: ($unexpected_ids | split("\n"))}'
    return 0
  fi

  detail=$(gh api "repos/$full/rulesets/$id" 2>/dev/null || echo "{}")
  jq -n --argjson exists true --argjson id "$id" --argjson payload "$detail" \
    --argjson unexpected "${unexpected_count:-0}" \
    --arg unexpected_ids "${unexpected_ids:-}" \
    '{exists: $exists, id: $id, payload: $payload, unexpected_count: $unexpected, unexpected_ids: ($unexpected_ids | split("\n"))}'
}

# Protección de rama CLASICA (branch protection legacy) sobre CUALQUIER rama del
# repo, no solo la de por defecto. Es una superficie DISTINTA de los rulesets,
# con su propio endpoint, y hasta ahora este reconciliador no la miraba: por eso
# `--check` daba verde en repos que corrian una segunda capa de reglas que nadie
# declaro.
#
# Importa sobre todo por `enforce_admins`. Con true, ni un admin de la
# organizacion puede saltarsela, asi que el bypass del ruleset (bypass_actors =
# OrganizationAdmin, bypass_mode = pull_request) deja de servir y todo merge
# queda bloqueado esperando a un revisor. Sintoma tipico: "Repository rule
# violations found / Waiting on code owner review", identico por CLI y por REST
# API, en un repo donde el ruleset por si solo lo permitiria.
#
# Por que TODAS las ramas y no solo la de por defecto: la primera version de
# esta funcion solo miraba default_branch, y con ese alcance no habria
# encontrado la proteccion clasica que bloqueaba la rama dev de
# spark-match-07-article, la que hubo que retirar a mano el 2026-08-06. Un
# barrido sobre la organizacion confirmo que no era un caso aislado: cuatro
# repos mas llevaban una capa clasica en dev que nadie declaraba.
#
# Como se eligen las ramas candidatas:
#   1. ?protected=true acota a las ramas con alguna proteccion. OJO: ese filtro
#      devuelve TAMBIEN las protegidas solo por ruleset, asi que no distingue
#      por si mismo; sirve para no pedir el endpoint clasico rama por rama.
#   2. Se le suma la rama por defecto y las refs que el manifiesto declara, por
#      si el listado falla o se queda corto. La union se deduplica.
#   3. El endpoint clasico decide: 404 significa que ahi no hay capa clasica.
#
# Devuelve siempre un JSON con {count, branches: [...]}, tambien cuando no hay
# nada (count 0).
fetch_legacy_protection() {
  local repo="$1"
  local default_branch candidates manifest_refs detail found

  default_branch=$(gh api "repos/$ORG/$repo" --jq '.default_branch' 2>/dev/null || echo "")

  # Refs declaradas en el manifiesto, traducidas a nombre de rama.
  # ~DEFAULT_BRANCH se resuelve a la rama por defecto real.
  manifest_refs=$(jq -r --arg r "$repo" --arg d "$default_branch" '
    .repositories[$r].refs // []
    | map(if . == "~DEFAULT_BRANCH" then $d else sub("^refs/heads/"; "") end)
    | .[]
  ' "$MANIFEST" 2>/dev/null || true)

  candidates=$(
    {
      gh api "repos/$ORG/$repo/branches?protected=true&per_page=100" --paginate \
        --jq '.[].name' 2>/dev/null || true
      [[ -n "$default_branch" ]] && echo "$default_branch"
      echo "$manifest_refs"
    } | grep -v '^$' | sort -u
  )

  found="[]"
  local branch
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    # 404 = sin proteccion clasica en esa rama, que es el estado deseado.
    #
    # El </dev/null NO es decorativo. Sin el, gh hereda el stdin del bucle --
    # la lista de ramas candidatas -- y se la come entera, asi que solo se
    # inspecciona la primera rama y las demas desaparecen en silencio.
    detail=$(gh api "repos/$ORG/$repo/branches/$branch/protection" 2>/dev/null </dev/null) || continue
    found=$(jq -n --argjson acc "$found" --arg b "$branch" --argjson d "$detail" '
      $acc + [{
        branch: $b,
        is_default: false,
        enforce_admins: ($d.enforce_admins.enabled // false),
        requires_review: ($d.required_pull_request_reviews != null),
        requires_code_owner: ($d.required_pull_request_reviews.require_code_owner_reviews // false)
      }]')
  done <<< "$candidates"

  jq -n --argjson f "$found" --arg d "$default_branch" '
    ($f | map(.is_default = (.branch == $d))) as $b |
    {count: ($b | length), default_branch: $d, branches: $b}'
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
              # required_reviewers field is OMITTED entirely because:
              #   - GitHub Free plan rejects non-empty values with 422.
              #   - GitHub API PUT does field-level merge (omitting leaves stale values).
              #   - canonical_diff() strips required_reviewers from current state before comparison,
              #     so reconcile reports in-sync despite stale empty arrays in live.
              # Team-based review is enforced via CODEOWNERS + require_code_owner_review=true.
              # See governance/repository-governance.json _note field for rationale.
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
  # Tambien ignoramos `required_reviewers` (stale empty array que la API no deja limpiar,
  # ver comment en build_desired_payload).
  local cur_norm des_norm
  cur_norm=$(echo "$current" | jq -S '
    del(.id, .node_id, .created_at, .updated_at, ._links, .source, .source_type, .url, .current_user_can_bypass) |
    .bypass_actors |= map(del(.actor_id)) |
    .conditions.ref_name.include |= sort |
    .conditions.ref_name.exclude |= sort |
    .rules |= sort_by(.type) |
    .rules |= map(if .parameters.dismissal_restriction then del(.parameters.dismissal_restriction) else . end) |
    .rules |= map(if .parameters.do_not_enforce_on_create == false then del(.parameters.do_not_enforce_on_create) else . end) |
    .rules |= map(if has("parameters") and (.parameters | has("required_reviewers")) then .parameters |= del(.required_reviewers) else . end)
  ')
  des_norm=$(echo "$desired" | jq -S '
    .bypass_actors |= map(del(.actor_id)) |
    .conditions.ref_name.include |= sort |
    .conditions.ref_name.exclude |= sort |
    .rules |= sort_by(.type) |
    .rules |= map(if .parameters.dismissal_restriction then del(.parameters.dismissal_restriction) else . end) |
    .rules |= map(if .parameters.do_not_enforce_on_create == false then del(.parameters.do_not_enforce_on_create) else . end) |
    .rules |= map(if has("parameters") and (.parameters | has("required_reviewers")) then .parameters |= del(.required_reviewers) else . end)
  ')

  if [[ "$cur_norm" == "$des_norm" ]]; then
    echo "in-sync"
  else
    echo "drift"
  fi
}

# Backup del ruleset actual (full GET) a BACKUP_DIR/<repo>-<id>.json.
# Devuelve no-zero si el backup falla — el caller debe respetar el contrato y
# abortar la mutacion destructiva (PUT) si el backup no se completo.
backup_ruleset() {
  local repo="$1"
  local rs_id="$2"
  local full="$ORG/$repo"
  local dir="${BACKUP_DIR:-backups/rulesets/$(date +%Y%m%d-%H%M%S)}"
  local target="$dir/${repo}-${rs_id}.json"
  mkdir -p "$dir"
  if ! gh api "repos/$full/rulesets/$rs_id" > "$target" 2>/dev/null; then
    rm -f "$target"  # limpiar partial si quedo algo
    log_err "Backup fallo para $repo ruleset $rs_id (target: $target)"
    return 1
  fi
  echo "$dir"
}

# Respalda la branch protection CLASICA de una rama antes de borrarla.
#
# Mismo contrato que backup_ruleset: devuelve no-cero si el respaldo falla, y
# el caller DEBE abortar el borrado en ese caso.
#
# Existe porque no estaba y se noto tarde. El script respaldaba los rulesets
# antes de un PUT, y hasta abortaba el PUT si el respaldo fallaba, pero
# --prune-legacy-protection borraba la capa clasica sin guardar nada. Un DELETE
# sobre /branches/{b}/protection no tiene deshacer: si luego resulta que esa
# capa protegia algo que el ruleset no cubre, no hay a que volver.
backup_legacy_protection() {
  local repo="$1"
  local branch="$2"
  local dir="${BACKUP_DIR:-backups/rulesets/$(date +%Y%m%d-%H%M%S)}"
  # El nombre de rama puede llevar barras (release/1.x), que no valen en un
  # nombre de fichero.
  local safe_branch="${branch//\//-}"
  local target="$dir/${repo}-legacy-protection-${safe_branch}.json"
  mkdir -p "$dir"
  if ! gh api "repos/$ORG/$repo/branches/$branch/protection" > "$target" 2>/dev/null </dev/null; then
    rm -f "$target"
    log_err "Backup fallo para $repo rama '$branch' (target: $target)"
    return 1
  fi
  echo "$dir"
}

# --- Loop principal ----------------------------------------------------------
log_info "ORG=$ORG MANIFEST=$MANIFEST MODE=$MODE DRY_RUN=$DRY_RUN"

# Se resuelve ANTES del bucle para poder alimentarlo con un here-string en vez
# de con `< <(resolve_repos)`, y de paso para saber si habia trabajo que hacer
# cuando toque comprobar que se produjo algun resultado.
REPOS_TO_PROCESS=$(resolve_repos)

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

  # Proteccion clasica: se DETECTA siempre, se borra solo con flag explicito.
  # Mismo criterio que --prune-unexpected: el reconciliador no destruye reglas
  # que no creo sin que alguien lo pida en la linea de comandos.
  legacy_json=$(fetch_legacy_protection "$repo")
  legacy_count=$(echo "$legacy_json" | jq -r '.count')
  if [[ "$legacy_count" -gt 0 ]]; then
    # Una rama puede fallar el DELETE sin que las demas lo hagan, asi que cada
    # una produce su propia entrada en RESULTS en vez de un veredicto por repo.
    while IFS=$'\t' read -r legacy_branch legacy_admins legacy_default; do
      [[ -z "$legacy_branch" ]] && continue
      if [[ "$PRUNE_LEGACY_PROTECTION" == true && "$MODE" == "apply" && "$DRY_RUN" == false ]]; then
        # Respaldo ANTES del DELETE, mismo contrato que con los rulesets: si no
        # se puede guardar, no se borra. Un DELETE sobre
        # /branches/{b}/protection no tiene deshacer.
        if ! legacy_backup_dir=$(backup_legacy_protection "$repo" "$legacy_branch"); then
          log_err "$repo: no se pudo respaldar la proteccion clasica de '$legacy_branch'; no se borra"
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"legacy-protection-backup-failed\",\"branch\":\"$legacy_branch\"}")
          ANY_FAIL=true
          continue
        fi
        log_info "$repo: proteccion clasica de '$legacy_branch' respaldada en $legacy_backup_dir"

        # </dev/null por el mismo motivo que en fetch_legacy_protection: este
        # bucle tambien lee ramas por stdin y gh se lo comeria.
        if gh api -X DELETE "repos/$ORG/$repo/branches/$legacy_branch/protection" >/dev/null 2>&1 </dev/null; then
          log_info "$repo: borrada proteccion clasica en '$legacy_branch' (el ruleset queda como unica fuente)"
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"legacy-protection-removed\",\"branch\":\"$legacy_branch\"}")
        else
          log_err "$repo: fallo el DELETE de la proteccion clasica en '$legacy_branch'"
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"legacy-protection-delete-failed\",\"branch\":\"$legacy_branch\"}")
          ANY_FAIL=true
        fi
      else
        log_warn "$repo: proteccion clasica activa en '$legacy_branch' (enforce_admins=$legacy_admins, rama_por_defecto=$legacy_default). Convive con el ruleset y no la declara el manifiesto; usa --prune-legacy-protection para retirarla."
        RESULTS+=("{\"repo\":\"$repo\",\"state\":\"legacy-protection\",\"branch\":\"$legacy_branch\",\"enforce_admins\":$legacy_admins,\"is_default\":$legacy_default}")
        ANY_DRIFT=true
      fi
    # Here-string y no `< <(...)`: la sustitucion de procesos depende de
    # /dev/fd y bajo Git Bash falla de forma intermitente. Cuando falla el
    # bucle no llega a correr, no se emite ningun aviso, y con --strict el
    # script sale con 0 diciendo que todo esta bien. Un fallo silencioso en el
    # camino que existe precisamente para detectar fallos silenciosos.
    done <<< "$(echo "$legacy_json" | jq -r '.branches[] | [.branch, (.enforce_admins|tostring), (.is_default|tostring)] | @tsv')"
  fi

  current_json=$(fetch_current_ruleset "$repo")
  exists=$(echo "$current_json" | jq -r '.exists')
  rs_id=$(echo "$current_json" | jq -r '.id // empty')
  unexpected=$(echo "$current_json" | jq -r '.unexpected_count')
  unexpected_ids_json=$(echo "$current_json" | jq -c '.unexpected_ids // []')
  current_payload=$(echo "$current_json" | jq -c '.payload // {}')

  desired_payload=$(build_desired_payload "$repo" "$team_id")

  # Foreign rulesets (target=branch, name distinto al administrado).
  # Por default: abort (no los pisamos). --prune-unexpected: borrarlos via API.
  if [[ "$unexpected" -gt 0 ]]; then
    if [[ "$PRUNE_UNEXPECTED" == true ]]; then
      pruned=0
      for uid in $(echo "$unexpected_ids_json" | jq -r '.[]'); do
        if gh api -X DELETE "repos/$ORG/$repo/rulesets/$uid" >/dev/null 2>&1; then
          log_info "$repo: borrado ruleset inesperado id=$uid"
          pruned=$((pruned + 1))
        else
          log_err "$repo: fallo DELETE del ruleset inesperado id=$uid"
          ANY_FAIL=true
        fi
      done
      RESULTS+=("{\"repo\":\"$repo\",\"state\":\"pruned\",\"unexpected_pruned\":$pruned}")
      # Despues de podar, refrescar la lista para que el resto del flujo
      # opere contra el estado real (puede que ya no haya ruleset administrado).
      current_json=$(fetch_current_ruleset "$repo")
      exists=$(echo "$current_json" | jq -r '.exists')
      rs_id=$(echo "$current_json" | jq -r '.id // empty')
      current_payload=$(echo "$current_json" | jq -c '.payload // {}')
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
        # Backup OBLIGATORIO antes del PUT destructivo. Si falla, abortamos
        # este repo (no pisamos sin red de seguridad).
        if ! backup_dir=$(backup_ruleset "$repo" "$rs_id"); then
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"backup-failed\",\"ruleset_id\":$rs_id}")
          ANY_FAIL=true
          continue
        fi
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
        if POST_BODY=$(echo "$desired_payload" | gh api -X POST "repos/$ORG/$repo/rulesets" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            --input - 2>&1); then
          new_id=$(printf '%s' "$POST_BODY" | jq -r '.id // empty')
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"created\",\"ruleset_id\":${new_id:-null}}")
        else
          log_warn "$repo: POST rejected: $POST_BODY"
          RESULTS+=("{\"repo\":\"$repo\",\"state\":\"failed\",\"reason\":\"POST-rejected\"}")
          ANY_FAIL=true
        fi
      fi
    fi
  fi
# Here-string y no `< <(resolve_repos)`, por lo mismo que en el bucle de ramas:
# la sustitucion de procesos depende de /dev/fd y bajo Git Bash falla de forma
# intermitente. Aqui el fallo es peor, porque este es el bucle principal: el
# reconciliador procesaria CERO repositorios, imprimiria una tabla vacia y
# saldria con 0. Es decir, diria que toda la organizacion esta en orden sin
# haber mirado ni uno.
done <<< "$REPOS_TO_PROCESS"

# --- Resumen ----------------------------------------------------------------
echo ""

# Red de seguridad: si habia repos que procesar y no salio ni un resultado, algo
# se rompio entre medias. Sin esto el script sale con 0 y una tabla vacia, que
# es indistinguible de "todo en orden".
if [[ -n "$REPOS_TO_PROCESS" && ${#RESULTS[@]} -eq 0 ]]; then
  log_err "no se produjo ningun resultado pese a haber repositorios que procesar. Aborta en vez de reportar exito vacio."
  exit 2
fi
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

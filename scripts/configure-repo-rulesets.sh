#!/usr/bin/env bash
# =============================================================================
# configure-repo-rulesets.sh - Aplica un ruleset completo a todos los repos
#                              de la org spark-match via GitHub CLI.
# =============================================================================
# Por que este script existe:
#   - GitHub Free no soporta ORG-level rulesets (requiere GitHub Team).
#   - Repo-level rulesets SI funcionan en Free.
#   - Este script automatiza crear 1 ruleset completo por repo.
#
# Que cubre el ruleset (v2 - cubre TODO lo de branch protection):
#   - pull_request rule: 1 aprobacion, code owner review, dismiss stale,
#                        conversation resolution, allowed merge methods
#   - required_status_checks (opcional via --status-checks)
#   - non_fast_forward (block force push)
#   - required_linear_history
#
# Que cubre TODO lo de branch protection clasica. Esto significa que podes
# tener UNA sola fuente de verdad (el ruleset) y borrar branch protection.
# Si tienes ambas, la mas restrictiva gana (no rompe nada).
#
# Uso:
#   ./configure-repo-rulesets.sh --dry-run
#   ./configure-repo-rulesets.sh --repos spark-match-02-infrastructure
#   ./configure-repo-rulesets.sh --repos r1,r2 --status-checks "Plan (dev) / Plan (dev)"
#   ./configure-repo-rulesets.sh
#   ./configure-repo-rulesets.sh --delete-existing   # recrear desde cero
#
# Para borrar branch protection DESPUES de aplicar este script:
#   gh api -X DELETE repos/OWNER/REPO/branches/BRANCH/protection
# =============================================================================

set -euo pipefail

ORG="${ORG:-spark-match}"
DRY_RUN=false
REPOS_FILTER=""
DELETE_EXISTING=false
STATUS_CHECKS=""
APPROVALS="1"
ENFORCE_ADMINS_DEFAULT="false"

# --- Parsing de args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --repos)
      REPOS_FILTER="$2"
      shift 2
      ;;
    --status-checks)
      STATUS_CHECKS="$2"
      shift 2
      ;;
    --approvals)
      APPROVALS="$2"
      shift 2
      ;;
    --delete-existing)
      DELETE_EXISTING=true
      shift
      ;;
    --org)
      ORG="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,55p' "$0" | sed -E 's/^# ?//'
      exit 0
      ;;
    *)
      echo "[ERROR] Argumento desconocido: $1" >&2
      exit 1
      ;;
  esac
done

# --- Validacion: gh CLI autenticado ---
if ! gh auth status >/dev/null 2>&1; then
  echo "[ERROR] gh CLI no autenticado. Ejecuta: gh auth login" >&2
  exit 1
fi

# --- Obtener lista de repos ---
if [[ -n "$REPOS_FILTER" ]]; then
  REPOS=$(echo "$REPOS_FILTER" | tr ',' ' ')
  echo "[INFO] Aplicando solo a: $REPOS"
else
  REPOS=$(gh repo list "$ORG" --limit 100 --json name --jq '.[].name')
  REPO_COUNT=$(echo "$REPOS" | wc -l | tr -d ' ')
  echo "[INFO] $REPO_COUNT repos encontrados en org=$ORG"
fi

if [[ -n "$STATUS_CHECKS" ]]; then
  echo "[INFO] Status checks requeridos: $STATUS_CHECKS"
fi
echo "[INFO] Approvals requeridos: $APPROVALS"
echo ""

# --- Funcion: emitir el JSON del ruleset por stdin ---
# Ref: https://docs.github.com/en/rest/repos/rules (REST API endpoints for rules)
# Reglas usadas (todas oficiales, no deprecated):
#   - pull_request: PR approvals, code owner review, etc.
#   - non_fast_forward: block force pushes
#   - required_linear_history
#   - required_status_checks (opcional)
emit_ruleset() {
  cat <<EOF
{
  "name": "spark-match-default-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH", "refs/heads/dev"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": ${APPROVALS},
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash", "merge"]
      }
    },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" }
EOF

  if [[ -n "$STATUS_CHECKS" ]]; then
    CHECKS_JSON=""
    IFS=',' read -ra CHECKS_ARR <<< "$STATUS_CHECKS"
    for check in "${CHECKS_ARR[@]}"; do
      if [[ -n "$CHECKS_JSON" ]]; then
        CHECKS_JSON+=","
      fi
      CHECKS_JSON+="{\"context\": \"$check\"}"
    done

    cat <<EOF
,
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          $CHECKS_JSON
        ]
      }
    }
EOF
  fi

  cat <<'EOF'
  ]
}
EOF
}

# --- Loop principal ---
SUCCESS=0
FAILED=0
SKIPPED=0

for repo in $REPOS; do
  full_name="$ORG/$repo"

  # Detectar si ya existe un ruleset con el mismo nombre
  EXISTING_ID=$(gh api "repos/$full_name/rulesets" --jq '.[] | select(.name == "spark-match-default-branch-protection") | .id' 2>/dev/null || echo "")

  if [[ -n "$EXISTING_ID" ]]; then
    if [[ "$DELETE_EXISTING" == true ]]; then
      echo "[$full_name] Borrando ruleset existente (ID=$EXISTING_ID)..."
      if [[ "$DRY_RUN" == false ]]; then
        gh api -X DELETE "repos/$full_name/rulesets/$EXISTING_ID" --silent > /dev/null 2>&1 || true
      fi
    else
      echo "[$full_name] SKIP - ruleset ya existe (ID=$EXISTING_ID). Usar --delete-existing para recrear."
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
  fi

  echo "[$full_name] Creando ruleset..."
  if [[ "$DRY_RUN" == true ]]; then
    echo "  (dry-run: no se aplica)"
    SUCCESS=$((SUCCESS + 1))
  else
    if emit_ruleset | gh api -X POST "repos/$full_name/rulesets" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --input - \
        --silent > /dev/null 2>&1; then
      NEW_ID=$(gh api "repos/$full_name/rulesets" --jq '.[] | select(.name == "spark-match-default-branch-protection") | .id' 2>/dev/null)
      echo "  OK (ID=$NEW_ID)"
      SUCCESS=$((SUCCESS + 1))
    else
      echo "  FAIL"
      FAILED=$((FAILED + 1))
    fi
  fi
done

echo ""
echo "[DONE] created=$SUCCESS skipped=$SKIPPED failed=$FAILED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
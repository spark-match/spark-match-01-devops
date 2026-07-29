#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# configure-merge-methods.sh
#
# Aplica una política uniforme de merge en TODOS los repos de la org
# `spark-match`. Por defecto, fuerza SOLO squash merge + delete branch on merge.
#
# Configuración aplicada:
#   - allow_squash_merge=true   (único método permitido)
#   - allow_merge_commit=false  (deshabilitado)
#   - allow_rebase_merge=false  (deshabilitado)
#   - delete_branch_on_merge=true
#   - squash_merge_commit_title="PR_TITLE"
#   - squash_merge_commit_message="PR_BODY"
#
# Uso:
#   ./configure-merge-methods.sh                  # aplica a todos los repos
#   ./configure-merge-methods.sh --dry-run       # muestra qué haría
#   ./configure-merge-methods.sh --repos r1,r2   # solo a esos repos
#   ./configure-merge-methods.sh --allow-merge    # también permite merge commit
#   ./configure-merge-methods.sh --allow-rebase   # también permite rebase
#
# Requiere: gh CLI autenticado con permisos de admin en la org.
# =============================================================================

set -euo pipefail

ORG="${ORG:-spark-match}"
SQUASH_TITLE="${SQUASH_TITLE:-PR_TITLE}"
SQUASH_MSG="${SQUASH_MSG:-PR_BODY}"
DRY_RUN=false
ALLOW_MERGE=false
ALLOW_REBASE=false
REPOS_OVERRIDE=""

usage() {
  sed -n '2,/^# ====/p' "$0" | sed 's/^# \{0,1\}//'
}

# Help is not an error: --help / -h exit 0.
# Argument parse errors exit 2 (per gh-CLI convention).
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=true; shift ;;
    --repos)       REPOS_OVERRIDE="$2"; shift 2 ;;
    --allow-merge) ALLOW_MERGE=true; shift ;;
    --allow-rebase) ALLOW_REBASE=true; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "ERROR: argumento desconocido: $1" >&2; usage; exit 2 ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI no instalado. Instalar desde https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI no autenticado. Ejecutar: gh auth login" >&2
  exit 1
fi

echo "=== Configurando merge methods en $ORG ==="
echo "    allow_squash_merge=true"
echo "    allow_merge_commit=$ALLOW_MERGE"
echo "    allow_rebase_merge=$ALLOW_REBASE"
echo "    delete_branch_on_merge=true"
[[ "$DRY_RUN" == "true" ]] && echo "    (DRY-RUN: no se aplicarán cambios)"
echo ""

if [[ -n "$REPOS_OVERRIDE" ]]; then
  IFS=',' read -ra REPOS <<< "$REPOS_OVERRIDE"
  REPOS=("${REPOS[@]/#/$ORG/}")
else
  # IMPORTANT: do not use `mapfile -t REPOS < <(gh api ...)` here. Process
  # substitution swallows gh's exit code (mapfile's own exit is 0), so a
  # failed listing silently leaves REPOS empty and the script exits 0.
  LISTING=$(gh api "orgs/$ORG/repos" --paginate --jq '.[] | select(.is_template == false) | .full_name') || {
    echo "ERROR: no se pudo listar los repos de $ORG (gh api fallo). Revisar auth y permisos." >&2
    exit 1
  }
  if [[ -z "$LISTING" ]]; then
    echo "ERROR: $ORG no tiene repos (o ninguno es candidato). Nada que hacer." >&2
    exit 1
  fi
  mapfile -t REPOS <<< "$LISTING"
fi

printf "%-50s | %-7s | %-7s | %-7s | %-7s\n" "REPO" "SQUASH" "MERGE" "REBASE" "DEL_BR"
printf "%-50s-+-%-7s-+-%-7s-+-%-7s-+-%-7s\n" "--------------------------------------------------" "-------" "-------" "-------" "-------"

ANY_FAIL=false

for REPO in "${REPOS[@]}"; do
  REPO_NAME=$(basename "$REPO")

  if [[ "$DRY_RUN" == "true" ]]; then
    CUR=$(gh api "repos/$REPO" --jq '{
      s: .allow_squash_merge, m: .allow_merge_commit,
      r: .allow_rebase_merge, d: .delete_branch_on_merge
    } | "s=\(.s) m=\(.m) r=\(.r) d=\(.d)"' 2>/dev/null)
    printf "%-50s | %s (dry-run, would set squash=true merge=%s rebase=%s del=true)\n" \
      "$REPO_NAME" "$CUR" "$ALLOW_MERGE" "$ALLOW_REBASE"
    continue
  fi

  # Use -F (typed) for booleans so gh encodes them as JSON true/false,
  # NOT the strings "true"/"false" (which would round-trip as the string
  # and leave allow_merge_commit/allow_rebase_merge effectively enabled).
  if ! RESULT=$(gh api -X PATCH "repos/$REPO" \
      -F allow_squash_merge=true \
      -F allow_merge_commit="$ALLOW_MERGE" \
      -F allow_rebase_merge="$ALLOW_REBASE" \
      -F squash_merge_commit_title="$SQUASH_TITLE" \
      -F squash_merge_commit_message="$SQUASH_MSG" \
      -F delete_branch_on_merge=true \
      --jq '{
        s: .allow_squash_merge, m: .allow_merge_commit,
        r: .allow_rebase_merge, d: .delete_branch_on_merge
      } | "s=\(.s) m=\(.m) r=\(.r) d=\(.d)"' 2>&1); then
    echo "ERROR: PATCH rejected for $REPO: $RESULT" >&2
    ANY_FAIL=true
    continue
  fi

  printf "%-50s | %s\n" "$REPO_NAME" "$RESULT"
done

echo ""
echo "=== Hecho ==="
echo ""
echo "Notas:"
echo "  - El repo .github (perfil) tambien fue configurado."
echo "  - Los repos tipo 'template' se omiten (se configuran al crear nuevos repos)."
echo "  - Para revertir o re-aplicar: ejecutar este script de nuevo."

if [[ "$ANY_FAIL" == "true" ]]; then
  exit 1
fi

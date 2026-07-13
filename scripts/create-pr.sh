#!/usr/bin/env bash
# =============================================================================
# create-pr.sh — Helper para crear PRs con body bien formateado (Linux/Git Bash)
# =============================================================================
# Uso:
#   ./create-pr.sh --base dev --head feat/mi-feature \
#                  --title "feat: mi feature" \
#                  --body-file ./pr-body.md \
#                  --assignee ahincho \
#                  --labels enhancement,infrastructure
#
# Por que existe:
#   `gh pr create --body` con texto inline a veces interpreta caracteres
#   especiales (em-dash, backticks, acentos) raro. La forma robusta es
#   escribir el body en un .md y pasarlo con --body-file. Ademas,
#   `gh api POST .../pulls --input pr-body.json` con `\n` literales
#   DENTRO del campo `body` los renderiza como texto literal en vez
#   de saltos de linea. Este script evita ambos problemas.
#
# Requisitos:
#   - gh CLI autenticado con cuenta que tenga push access al repo
#   - El branch HEAD debe estar pusheado al remote
# =============================================================================

set -euo pipefail

BASE=""
HEAD=""
TITLE=""
BODY_FILE=""
ASSIGNEE=""
LABELS=""
REPO=""

usage() {
    echo "Usage: $0 --base <branch> --head <branch> --title <text> --body-file <path> [options]"
    echo ""
    echo "Options:"
    echo "  --base <branch>         Base branch (required)"
    echo "  --head <branch>         Head branch (required)"
    echo "  --title <text>          PR title (required)"
    echo "  --body-file <path>       Path to markdown body file (required)"
    echo "  --assignee <user>       GitHub assignee"
    echo "  --labels <l1,l2,...>     Comma-separated labels"
    echo "  --repo <owner/repo>     Override repo (default: auto-detect from origin)"
    echo "  --no-wait               Don't wait for status checks"
    echo "  --help                  Show this help"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --base) BASE="$2"; shift 2 ;;
        --head) HEAD="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --body-file) BODY_FILE="$2"; shift 2 ;;
        --assignee) ASSIGNEE="$2"; shift 2 ;;
        --labels) LABELS="$2"; shift 2 ;;
        --repo) REPO="$2"; shift 2 ;;
        --no-wait) NO_WAIT=1; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Validar argumentos requeridos
if [[ -z "$BASE" || -z "$HEAD" || -z "$TITLE" || -z "$BODY_FILE" ]]; then
    echo "Error: --base, --head, --title, --body-file are required"
    usage
fi

if [[ ! -f "$BODY_FILE" ]]; then
    echo "Error: body file not found: $BODY_FILE"
    exit 1
fi

# Auto-detectar repo si no se pasa
if [[ -z "$REPO" ]]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$REMOTE_URL" =~ github\.com[:/](.+)/(.+)\.git$ ]]; then
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        echo "Error: cannot auto-detect repo from remote URL: $REMOTE_URL"
        echo "Use --repo owner/repo"
        exit 1
    fi
fi

echo "=== Creating PR ==="
echo "Repo:     $REPO"
echo "Base:     $BASE"
echo "Head:     $HEAD"
echo "Title:    $TITLE"
echo "Body:     $BODY_FILE"
echo "Assignee: $ASSIGNEE"
echo "Labels:   $LABELS"
echo ""

# Construir argumentos de gh pr create
GH_ARGS=(
    "pr" "create"
    "--repo" "$REPO"
    "--base" "$BASE"
    "--head" "$HEAD"
    "--title" "$TITLE"
    "--body-file" "$BODY_FILE"
)

if [[ -n "$ASSIGNEE" ]]; then
    GH_ARGS+=("--assignee" "$ASSIGNEE")
fi

if [[ -n "$LABELS" ]]; then
    GH_ARGS+=("--label" "$LABELS")
fi

# Ejecutar gh pr create
gh "${GH_ARGS[@]}"

# Extraer PR number del output
PR_URL=$(gh pr list --repo "$REPO" --head "$HEAD" --json url --jq '.[0].url')
PR_NUMBER=$(echo "$PR_URL" | sed -E 's|.*/pull/([0-9]+).*|\1|')

echo ""
echo "PR #$PR_NUMBER created: $PR_URL"
echo ""

# Esperar checks si no se pidio --no-wait
if [[ -z "${NO_WAIT:-}" ]]; then
    echo "Esperando checks..."
    TIMEOUT=600
    ELAPSED=0
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        CHECKS=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json statusCheckRollup 2>/dev/null)
        PENDING=$(echo "$CHECKS" | jq '[.statusCheckRollup[] | select(.status == "IN_PROGRESS" or .status == "PENDING" or .status == "QUEUED")] | length')
        if [[ "$PENDING" == "0" ]]; then
            break
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done

    # Mostrar resultado final
    FINAL=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json state,statusCheckRollup 2>/dev/null)
    echo ""
    echo "Checks: $(echo "$FINAL" | jq -r '.statusCheckRollup[]? | "\(.name)=\(.conclusion // "pending")"' | tr '\n' ' ')"
    echo "State: $(echo "$FINAL" | jq -r '.state')"
fi
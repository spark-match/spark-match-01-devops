#!/usr/bin/env bash
# =============================================================================
# apply-strict-rulesets.sh - Aplica rulesets con bypass=OrganizationAdmin:pull_request
# =============================================================================
# Por que este script existe:
#   El bypass_mode "always" permite a OrganizationAdmin saltarse TODO, incluso
#   pushear directo a main. Esto rompe la convencion del repo de que todos los
#   cambios pasen por PR. Cambiamos a "pull_request" (admin puede mergear
#   PRs sin cumplir reglas de review, pero NO puede pushear directo).
#
# Uso:
#   ./apply-strict-rulesets.sh
# =============================================================================

set -euo pipefail

ORG="${ORG:-spark-match}"

emit_pull_request_01_devops() {
  cat <<'EOF'
{
  "name": "spark-match-default-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": null,
      "actor_type": "OrganizationAdmin",
      "bypass_mode": "pull_request"
    }
  ],
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
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash", "merge"]
      }
    },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {"context": "actionlint"},
          {"context": "gitleaks"},
          {"context": "yamllint"}
        ]
      }
    }
  ]
}
EOF
}

emit_pull_request_02_infra() {
  cat <<'EOF'
{
  "name": "spark-match-default-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": null,
      "actor_type": "OrganizationAdmin",
      "bypass_mode": "pull_request"
    }
  ],
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
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash", "merge"]
      }
    },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {"context": "Plan (dev) / Plan (dev)"},
          {"context": "Checkov"}
        ]
      }
    }
  ]
}
EOF
}

emit_pull_request_03_backend() {
  cat <<'EOF'
{
  "name": "spark-match-default-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": null,
      "actor_type": "OrganizationAdmin",
      "bypass_mode": "pull_request"
    }
  ],
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
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash", "merge"]
      }
    },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" }
  ]
}
EOF
}

apply_to_repo() {
  local repo="$1"
  local payload="$2"
  local full_name="$ORG/$repo"

  local existing_id=$(gh api "repos/$full_name/rulesets" --jq '.[] | select(.name == "spark-match-default-branch-protection") | .id' 2>/dev/null || echo "")
  if [[ -n "$existing_id" ]]; then
    echo "[$full_name] Borrando ruleset existente (ID=$existing_id)..."
    gh api -X DELETE "repos/$full_name/rulesets/$existing_id" --silent > /dev/null 2>&1
  fi

  echo "[$full_name] Creando ruleset con bypass_mode=pull_request..."
  echo "$payload" | gh api -X POST "repos/$full_name/rulesets" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --input - > /dev/null 2>&1

  local new_id=$(gh api "repos/$full_name/rulesets" --jq '.[] | select(.name == "spark-match-default-branch-protection") | .id' 2>/dev/null)
  echo "[$full_name] OK (ID=$new_id)"
}

# Verificar auth
if ! gh auth status >/dev/null 2>&1; then
  echo "[ERROR] gh CLI no autenticado. Ejecuta: gh auth login" >&2
  exit 1
fi

# Aplicar a los 3 repos
apply_to_repo "spark-match-01-devops" "$(emit_pull_request_01_devops)"
apply_to_repo "spark-match-02-infrastructure" "$(emit_pull_request_02_infra)"
apply_to_repo "spark-match-03-backend" "$(emit_pull_request_03_backend)"

echo ""
echo "[DONE] rulesets applied con bypass_mode=pull_request (admin no puede pushear directo)"
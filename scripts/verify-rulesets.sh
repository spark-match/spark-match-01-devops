#!/usr/bin/env bash
set -euo pipefail
gh auth switch --user ahincho 2>&1 | head -1
for repo in spark-match-01-devops spark-match-02-infrastructure spark-match-03-backend; do
    echo ""
    echo "=== $repo ==="
    raw=$(gh api "repos/spark-match/$repo/rulesets" 2>&1 || echo "[]")
    id=$(echo "$raw" | jq -r '.[0].id // empty' 2>/dev/null || echo "")
    if [[ -n "$id" && "$id" != "null" ]]; then
        detail=$(gh api "repos/spark-match/$repo/rulesets/$id" 2>&1)
        bypass=$(echo "$detail" | jq -r '.bypass_actors[0].bypass_mode // "none"')
        current=$(echo "$detail" | jq -r '.current_user_can_bypass // "unknown"')
        echo "  ID=$id"
        echo "  bypass_mode=$bypass"
        echo "  current_user_can_bypass=$current"
    else
        echo "  NO RULESETS"
    fi
done
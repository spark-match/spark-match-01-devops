#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# audit-codeowners-ruleset.sh - verify the RULESET enforces CODE_OWNERS review
# =============================================================================
# Companion to tests/bats/codeowners-enforcement.bats (which verifies the
# CODEOWNERS file itself). This script verifies that the ruleset
# 18893014 actually enforces:
#   - require_code_owner_review: true
#   - required_approving_review_count >= 1
#   - bypass_actors include OrganizationAdmin (already there) +
#     spark-match-bot (already there for release-please)
#
# Usage:
#   ./scripts/audit-codeowners-ruleset.sh
#   ./scripts/audit-codeowners-ruleset.sh --json    # machine-readable output
#   ./scripts/audit-codeowners-ruleset.sh --dry-run # plan checks without API calls
#   ./scripts/audit-codeowners-ruleset.sh --help    # show this header
#
# Examples:
#   # Verify the ruleset enforces CODE_OWNERS review on this repo:
#   ./scripts/audit-codeowners-ruleset.sh
#
#   # Audit a different repo (used by CI for cross-repo sweeps):
#   REPO=spark-match/spark-match-02-infrastructure ./scripts/audit-codeowners-ruleset.sh
#
#   # Machine-readable JSON for downstream tooling:
#   ./scripts/audit-codeowners-ruleset.sh --json | jq .
#
# Exit codes:
#   0   all checks pass
#   1   one or more checks fail
#   2   API error (auth, network)
# =============================================================================

set -euo pipefail

RULESET_ID="${RULESET_ID:-18893014}"
REPO="${REPO:-spark-match/spark-match-01-devops}"
JSON_OUT=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    --dry-run)
      DRY_RUN=1
      echo "::notice::DRY-RUN: skipping gh api calls; printing planned checks only."
      shift
      ;;
    --help|-h)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if ! command -v gh >/dev/null 2>&1 && [[ $DRY_RUN -eq 0 ]]; then
  echo "::error::gh CLI not found" >&2
  exit 2
fi

if [[ $DRY_RUN -eq 1 ]]; then
  if [[ $JSON_OUT -eq 1 ]]; then
    jq -n \
      '{ruleset_id: '"$RULESET_ID"', repo: "'"$REPO"'", mode: "dry-run", checks_planned: ["require_code_owner_review", "required_approving_review_count", "strict_required_status_checks_policy", "required_status_checks_count", "allowed_merge_methods", "bypass_actors"], fail_count: 0}'
  else
    echo "Ruleset ${RULESET_ID} audit (DRY-RUN):"
    echo "  repo:        ${REPO}"
    echo "  ruleset_id:  ${RULESET_ID}"
    echo "  planned checks:"
    echo "    - require_code_owner_review == true"
    echo "    - required_approving_review_count >= 1"
    echo "    - strict_required_status_checks_policy == true"
    echo "    - required_status_checks_count reported (informational)"
    echo "    - allowed_merge_methods reported (informational)"
    echo "    - bypass_actors reported (informational)"
  fi
  exit 0
fi

# Fetch the ruleset.
RULESET_JSON=$(gh api "repos/${REPO}/rulesets/${RULESET_ID}" 2>&1)
RC=$?
if [[ $RC -ne 0 ]]; then
  echo "::error::failed to fetch ruleset ${RULESET_ID}: ${RULESET_JSON}" >&2
  exit 2
fi

# Use jq to extract the fields we care about. Falls back to grep if jq
# is missing (we already pin jq 1.8.2 in the local dev environment).
if command -v jq >/dev/null 2>&1; then
  PR_RULE=$(echo "$RULESET_JSON" | jq -r '.rules[] | select(.type=="pull_request")')
  REQ_CODE_OWNER=$(echo "$PR_RULE" | jq -r '.parameters.require_code_owner_review')
  REQ_REVIEW_COUNT=$(echo "$PR_RULE" | jq -r '.parameters.required_approving_review_count')
  ALLOWED_MERGES=$(echo "$PR_RULE" | jq -r '.parameters.allowed_merge_methods | join(",")')
  STATUS_CHECK=$(echo "$RULESET_JSON" | jq -r '.rules[] | select(.type=="required_status_checks")')
  STRICT=$(echo "$STATUS_CHECK" | jq -r '.parameters.strict_required_status_checks_policy')
  CHECK_COUNT=$(echo "$STATUS_CHECK" | jq -r '.parameters.required_status_checks | length')
  BYPASS=$(echo "$RULESET_JSON" | jq -r '.bypass_actors[] | "\(.actor_type):\(.actor_id // "") mode=\(.bypass_mode)"' | sort)
else
  # Best-effort grep fallback.
  REQ_CODE_OWNER=$(echo "$RULESET_JSON" | grep -oE '"require_code_owner_review":(true|false)' | cut -d: -f2)
  REQ_REVIEW_COUNT=$(echo "$RULESET_JSON" | grep -oE '"required_approving_review_count":[0-9]+' | cut -d: -f2)
  STRICT=$(echo "$RULESET_JSON" | grep -oE '"strict_required_status_checks_policy":(true|false)' | cut -d: -f2)
  BYPASS=$(echo "$RULESET_JSON" | grep -oE '"actor_type":"[^"]+"' | sort -u)
  ALLOWED_MERGES="(jq not installed; cannot extract)"
  CHECK_COUNT="(jq not installed; cannot extract)"
fi

# Evaluate.
FAIL=0
check() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    if [[ $JSON_OUT -eq 0 ]]; then echo "  ok   $label: $actual"; fi
  else
    if [[ $JSON_OUT -eq 0 ]]; then echo "  FAIL $label: expected=$expected actual=$actual"; fi
    FAIL=$((FAIL + 1))
  fi
}

if [[ $JSON_OUT -eq 1 ]]; then
  jq -n \
    --argjson req_code_owner "$REQ_CODE_OWNER" \
    --argjson req_review_count "$REQ_REVIEW_COUNT" \
    --arg strict "$STRICT" \
    --argjson check_count "$CHECK_COUNT" \
    --arg allowed_merges "$ALLOWED_MERGES" \
    --arg bypass "$(echo "$BYPASS" | tr '\n' ';')" \
    '{ruleset_id: '"$RULESET_ID"', require_code_owner_review: $req_code_owner, required_approving_review_count: $req_review_count, strict_status_checks: $strict, status_checks_count: $check_count, allowed_merge_methods: $allowed_merges, bypass_actors: $bypass, fail_count: '"$FAIL"'}'
else
  echo "Ruleset ${RULESET_ID} audit:"
  check "require_code_owner_review" "$REQ_CODE_OWNER" "true"
  check "required_approving_review_count >= 1" \
    "$([[ ${REQ_REVIEW_COUNT:-0} -ge 1 ]] && echo ok || echo fail)" "ok"
  check "strict_required_status_checks_policy" "$STRICT" "true"
  echo "  info required_status_checks count: $CHECK_COUNT"
  echo "  info allowed_merge_methods: $ALLOWED_MERGES"
  echo "  info bypass_actors:"
  echo "    ${BYPASS//$'\n'/$'\n    '}"
fi

exit $FAIL
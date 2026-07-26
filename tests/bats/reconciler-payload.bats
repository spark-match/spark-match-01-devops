#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reconciler-payload.bats - build_desired_payload correctness
# =============================================================================
# Tests the jq-based payload construction (lines 188-251 of the script) by
# extracting the function via eval and invoking it directly. Validates the
# shape of the ruleset JSON that the reconciler would PUT/POST.
# =============================================================================

load 'helpers/reconciler'

setup() {
  load 'helpers/reconciler'
  write_default_manifest
  export MANIFEST="$BATS_TEST_TMPDIR/fixtures/manifest.json"

  # Extract build_desired_payload() from the script into the current shell.
  fn_body=$(sed -n '/^build_desired_payload()/,/^}$/p' "$SCRIPT")
  eval "$fn_body"
}

teardown() {
  unset fn_body
}

# -----------------------------------------------------------------------------
# Top-level fields
# -----------------------------------------------------------------------------

@test "payload: top-level fields come from defaults (name, target, enforcement)" {
  payload=$(build_desired_payload "spark-match-foo" "12345")
  [[ "$(echo "$payload" | jq -r '.name')" == "spark-match-default-branch-protection" ]]
  [[ "$(echo "$payload" | jq -r '.target')" == "branch" ]]
  [[ "$(echo "$payload" | jq -r '.enforcement')" == "active" ]]
}

@test "payload: conditions.ref_name.include comes from repo.refs" {
  payload=$(build_desired_payload "spark-match-foo" "12345")
  [[ "$(echo "$payload" | jq -c '.conditions.ref_name.include')" == '["~DEFAULT_BRANCH"]' ]]

  payload=$(build_desired_payload "spark-match-bar" "12345")
  [[ "$(echo "$payload" | jq -c '.conditions.ref_name.include')" == '["~DEFAULT_BRANCH","refs/heads/dev"]' ]]
}

@test "payload: bypass_actors[0] comes from defaults (OrganizationAdmin, pull_request)" {
  payload=$(build_desired_payload "spark-match-foo" "12345")
  [[ "$(echo "$payload" | jq -r '.bypass_actors[0].actor_type')" == "OrganizationAdmin" ]]
  [[ "$(echo "$payload" | jq -r '.bypass_actors[0].bypass_mode')" == "pull_request" ]]
  [[ "$(echo "$payload" | jq -r '.bypass_actors[0].actor_id')" == "null" ]]
}

# -----------------------------------------------------------------------------
# pull_request rule
# -----------------------------------------------------------------------------

@test "payload: pull_request rule carries approvals + code owner review + squash-only" {
  payload=$(build_desired_payload "spark-match-foo" "12345")
  pr=$(echo "$payload" | jq '.rules[] | select(.type == "pull_request")')

  [[ "$(echo "$pr" | jq -r '.parameters.required_approving_review_count')" == "1" ]]
  [[ "$(echo "$pr" | jq -r '.parameters.require_code_owner_review')" == "true" ]]
  [[ "$(echo "$pr" | jq -r '.parameters.dismiss_stale_reviews_on_push')" == "true" ]]
  [[ "$(echo "$pr" | jq -r '.parameters.required_review_thread_resolution')" == "true" ]]
  [[ "$(echo "$pr" | jq -r '.parameters.require_last_push_approval')" == "false" ]]
  [[ "$(echo "$pr" | jq -c '.parameters.allowed_merge_methods')" == '["squash"]' ]]
}

@test "payload: required_reviewers[0] uses tonumber(team_id) as reviewer_id" {
  payload=$(build_desired_payload "spark-match-foo" "12345")
  reviewer_id=$(echo "$payload" | jq -r '.rules[0].parameters.required_reviewers[0].reviewer_id')
  [[ "$reviewer_id" == "12345" ]]
  [[ "$(echo "$payload" | jq -r '.rules[0].parameters.required_reviewers[0].reviewer_type')" == "Team" ]]
  [[ "$(echo "$payload" | jq -c '.rules[0].parameters.required_reviewers[0].file_patterns')" == '["**"]' ]]
}

# -----------------------------------------------------------------------------
# required_status_checks rule (conditional)
# -----------------------------------------------------------------------------

@test "payload: required_status_checks rule included when statusChecks.length > 0" {
  payload=$(build_desired_payload "spark-match-foo" "12345")  # 1 status check
  count=$(echo "$payload" | jq '[.rules[] | select(.type == "required_status_checks")] | length')
  [ "$count" -eq 1 ]

  contexts=$(echo "$payload" | jq -c '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks')
  [[ "$contexts" == '[{"context":"ci / ci"}]' ]]
}

@test "payload: required_status_checks rule omitted when statusChecks is empty" {
  payload=$(build_desired_payload "spark-match-bar" "12345")  # 0 status checks
  count=$(echo "$payload" | jq '[.rules[] | select(.type == "required_status_checks")] | length')
  [ "$count" -eq 0 ]
}

# -----------------------------------------------------------------------------
# Branch-protection rules (non_fast_forward, required_linear_history, deletion)
# -----------------------------------------------------------------------------

@test "payload: non_fast_forward + required_linear_history + deletion rules present when defaults allow" {
  payload=$(build_desired_payload "spark-match-foo" "12345")
  types=$(echo "$payload" | jq -r '[.rules[].type] | sort | join(",")')
  [[ "$types" == *"non_fast_forward"* ]]
  [[ "$types" == *"required_linear_history"* ]]
  [[ "$types" == *"deletion"* ]]
}

@test "payload: non_fast_forward rule omitted when defaults.blockForcePush=false" {
  # Build a manifest override with blockForcePush=false
  cat > "$BATS_TEST_TMPDIR/fixtures/manifest-no-forcepush.json" <<'EOF'
{
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
    "blockForcePush": false,
    "requireLinearHistory": true,
    "rulesetName": "test",
    "rulesetTarget": "branch",
    "rulesetEnforcement": "active"
  },
  "repositories": {
    "spark-match-foo": {
      "refs": ["~DEFAULT_BRANCH"],
      "reviewerTeam": "devops",
      "filePatterns": ["**"],
      "statusChecks": []
    }
  }
}
EOF
  MANIFEST="$BATS_TEST_TMPDIR/fixtures/manifest-no-forcepush.json"
  payload=$(build_desired_payload "spark-match-foo" "12345")
  types=$(echo "$payload" | jq -r '[.rules[].type] | sort | join(",")')
  [[ "$types" != *"non_fast_forward"* ]]
  [[ "$types" == *"required_linear_history"* ]]
  [[ "$types" == *"deletion"* ]]
}

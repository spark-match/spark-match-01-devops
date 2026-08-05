#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reusable-ecs-deploy.bats - regression guards for the ECS rolling deploy
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-ecs-deploy.yml"

@test "reusable-ecs-deploy: workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "reusable-ecs-deploy: declares workflow_call trigger" {
  run grep -E "^[[:space:]]+workflow_call:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-ecs-deploy: every input has type" {
  run grep -cE "^[[:space:]]+type: (string|boolean|number|choice)" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" -ge 11 ]
}

@test "reusable-ecs-deploy: the five service-identifying inputs are required" {
  for field in environment-name cluster-name service-name container-name image-uri; do
    run grep -E -A4 "^[[:space:]]+${field}:" "$WORKFLOW"
    [ "$status" -eq 0 ]
    [[ "$output" == *"required: true"* ]]
  done
}

@test "reusable-ecs-deploy: aws-region defaults to us-east-1" {
  run grep -E -A5 "^[[:space:]]+aws-region:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"us-east-1"* ]]
}

@test "reusable-ecs-deploy: waits for service stability by default" {
  # A deploy that does not wait reports green while tasks crash-loop.
  run grep -E -A5 "^[[:space:]]+wait-for-service-stability:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"default: true"* ]]
}

@test "reusable-ecs-deploy: task-definition-family defaults to empty (resolve from live service)" {
  # modules/agent-service sets lifecycle.ignore_changes on task_definition,
  # so the running revision -- not a file in the caller repo -- is the base.
  run grep -E -A6 "^[[:space:]]+task-definition-family:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"default: ''"* ]]
}

@test "reusable-ecs-deploy: strips read-only fields before RegisterTaskDefinition" {
  # DescribeTaskDefinition returns fields that RegisterTaskDefinition rejects.
  run grep -E "del\(\.taskDefinitionArn" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"revision"* ]]
  [[ "$output" == *"requiresAttributes"* ]]
  [[ "$output" == *"compatibilities"* ]]
}

@test "reusable-ecs-deploy: fails loudly when the service does not exist" {
  run grep -E "::error::service" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-ecs-deploy: deploy-role-arn input accepts string ARN" {
  run grep -E -A4 "^[[:space:]]+deploy-role-arn:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"OIDC role ARN"* ]]
}

@test "reusable-ecs-deploy: deploy-role-arn-secret input exists with AWS_DEPLOY_ROLE_ARN default" {
  run grep -E -A4 "^[[:space:]]+deploy-role-arn-secret:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"AWS_DEPLOY_ROLE_ARN"* ]]
}

@test "reusable-ecs-deploy: configure-aws-credentials uses dual-path (string input OR secret fallback)" {
  run grep -E -A3 "configure-aws-credentials-oidc-deploy-role" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"role-to-assume"* ]]
  [[ "$output" == *"inputs.deploy-role-arn != '' && inputs.deploy-role-arn || secrets[inputs.deploy-role-arn-secret]"* ]]
}

@test "reusable-ecs-deploy: AWS_DEPLOY_ROLE_ARN secret is optional (not required)" {
  run grep -E -A2 "^[[:space:]]+AWS_DEPLOY_ROLE_ARN:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"required: false"* ]]
}

@test "reusable-ecs-deploy: exposes task-definition-arn as a workflow output" {
  run grep -E -A3 "^[[:space:]]+task-definition-arn:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jobs.deploy.outputs.task-definition-arn"* ]]
}

@test "reusable-ecs-deploy: every action pinned to floating major (no SHA pins)" {
  run grep -E "uses: [^@]+@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-ecs-deploy: configure-aws-credentials pinned to floating major v6" {
  run grep -E "uses: aws-actions/configure-aws-credentials@v6$" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-ecs-deploy: amazon-ecs-render-task-definition pinned to floating major v1" {
  run grep -E "uses: aws-actions/amazon-ecs-render-task-definition@v1$" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-ecs-deploy: amazon-ecs-deploy-task-definition pinned to floating major v2" {
  run grep -E "uses: aws-actions/amazon-ecs-deploy-task-definition@v2$" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-ecs-deploy: internal composite referenced by branch, not tag" {
  # docs/VERSIONING.md: repos internos de spark-match se referencian por rama.
  run grep -E "uses: spark-match/spark-match-01-devops/.github/actions/validate-workflow-inputs@main" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-ecs-deploy: permissions id-token write + contents read + pull-requests write" {
  run grep -E -A6 "^permissions:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"id-token: write"* ]]
  [[ "$output" == *"contents: read"* ]]
  [[ "$output" == *"pull-requests: write"* ]]
}

@test "reusable-ecs-deploy: does NOT grant deployments write at workflow level" {
  # Deployments is governed by GH Environment binding, not workflow perms.
  run grep -E "deployments:.*write" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-ecs-deploy: does not declare concurrency" {
  # Reusable workflows cannot own concurrency; the caller owns it.
  run grep -E "^concurrency:" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-ecs-deploy: failure comment is guarded to pull_request events" {
  # Outside a PR there is nothing to comment on and the action would fail
  # for that reason instead of the deploy reason.
  run grep -E -A2 "name: notify-deploy-failure" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"github.event_name == 'pull_request'"* ]]
}

@test "reusable-ecs-deploy: env-isolates inputs in run blocks" {
  run grep -E "INPUTS_[A-Z_]+: \\\${{ inputs\\." "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-container-deploy-ecr: failure comment is guarded to pull_request events" {
  # Same fix applied to the sibling recipe: it declared pull-requests: write
  # nowhere and fired the comment on push events.
  ECR_WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-container-deploy-ecr.yml"
  run grep -E -A4 "name: notify-deploy-failure" "$ECR_WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"github.event_name == 'pull_request'"* ]]
}

@test "reusable-container-deploy-ecr: declares pull-requests write for the sticky comment" {
  ECR_WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-container-deploy-ecr.yml"
  run grep -E -A6 "^permissions:" "$ECR_WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull-requests: write"* ]]
}

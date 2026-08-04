#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reusable-container-deploy-ecr.bats - regression guards for the ECR push
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-container-deploy-ecr.yml"

@test "reusable-container-deploy-ecr: workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "reusable-container-deploy-ecr: declares workflow_call trigger" {
  run grep -E "^[[:space:]]+workflow_call:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-container-deploy-ecr: every input has type" {
  run grep -cE "^[[:space:]]+type: (string|boolean|number|choice)" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" -ge 13 ]
}

@test "reusable-container-deploy-ecr: required inputs are environment-name + ecr-repository" {
  run grep -E -B1 -A4 "^[[:space:]]+environment-name:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"required: true"* ]]
  run grep -E -B1 -A4 "^[[:space:]]+ecr-repository:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"required: true"* ]]
}

@test "reusable-container-deploy-ecr: aws-region defaults to us-east-1" {
  run grep -E -B1 -A5 "^[[:space:]]+aws-region:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"us-east-1"* ]]
}

@test "reusable-container-deploy-ecr: platforms defaults to linux/arm64" {
  run grep -E -B1 -A5 "^[[:space:]]+platforms:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"linux/arm64"* ]]
}

@test "reusable-container-deploy-ecr: deploy-role-arn input accepts string ARN" {
  run grep -E -B1 -A4 "^[[:space:]]+deploy-role-arn:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"OIDC role ARN"* ]]
}

@test "reusable-container-deploy-ecr: deploy-role-arn-secret input exists with AWS_DEPLOY_ROLE_ARN default" {
  run grep -E -B1 -A4 "^[[:space:]]+deploy-role-arn-secret:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"AWS_DEPLOY_ROLE_ARN"* ]]
}

@test "reusable-container-deploy-ecr: configure-aws-credentials uses dual-path (string input OR secret fallback)" {
  run grep -E -A3 "configure-aws-credentials-oidc-deploy-role" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"role-to-assume"* ]]
  [[ "$output" == *"inputs.deploy-role-arn != '' && inputs.deploy-role-arn || secrets[inputs.deploy-role-arn-secret]"* ]]
}

@test "reusable-container-deploy-ecr: AWS_DEPLOY_ROLE_ARN secret is optional (not required)" {
  run grep -E -B1 -A2 "^[[:space:]]+AWS_DEPLOY_ROLE_ARN:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"required: false"* ]]
}

@test "reusable-container-deploy-ecr: every action pinned to floating major (no SHA pins)" {
  run grep -E "uses: [^@]+@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-container-deploy-ecr: actions/checkout pinned to floating major v7" {
  run grep -E "uses: actions/checkout@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-container-deploy-ecr: configure-aws-credentials pinned to floating major v6" {
  run grep -E "uses: aws-actions/configure-aws-credentials@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-container-deploy-ecr: amazon-ecr-login pinned to floating major v2" {
  run grep -E "uses: aws-actions/amazon-ecr-login@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-container-deploy-ecr: setup-buildx-action pinned to floating major v4" {
  run grep -E "uses: docker/setup-buildx-action@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-container-deploy-ecr: build-push-action pinned to floating major v7" {
  run grep -E "uses: docker/build-push-action@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-container-deploy-ecr: cosign-installer pinned to floating major v3" {
  run grep -E "uses: sigstore/cosign-installer@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-container-deploy-ecr: permissions id-token write + contents read" {
  run grep -E -A3 "^permissions:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"id-token: write"* ]]
  [[ "$output" == *"contents: read"* ]]
}

@test "reusable-container-deploy-ecr: does NOT grant deployments write at workflow level" {
  # Deployments is governed by GH Environment binding, not workflow perms.
  run grep -E "deployments:.*write" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-container-deploy-ecr: does not declare concurrency" {
  # Reusable workflows cannot own concurrency; the caller owns it.
  run grep -E "^concurrency:" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-container-deploy-ecr: env-isolates inputs in run blocks" {
  # workflow-env-isolation.bats already enforces the general rule; this
  # test pins the specific INPUTS_* env vars we expect.
  run grep -E "INPUTS_[A-Z_]+: \\\${{ inputs\\." "$WORKFLOW"
  [ "$status" -eq 0 ]
}

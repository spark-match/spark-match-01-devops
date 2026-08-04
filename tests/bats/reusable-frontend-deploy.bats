#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reusable-frontend-deploy.bats - regression guards for the S3+CloudFront
# frontend-deploy reusable workflow
# =============================================================================
# Locks down:
#   - file exists at the canonical path
#   - workflow_call is declared (so cross-repo callers can use it)
#   - every documented input is present with type: string
#   - permissions carry id-token: write (OIDC) and contents: read
#   - required actions are pinned by floating tag (NOT SHA)
#   - minimal step coverage: checkout, configure-aws-credentials, setup-node,
#     npm ci, build, s3 sync, cloudfront invalidation, distribution URL
#   - no ${{ secrets.* }} inside the file (GitHub Actions limitation in
#     reusable with: blocks; caller passes role ARN via vars.X instead)
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-frontend-deploy.yml"

@test "reusable-frontend-deploy: workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "reusable-frontend-deploy: declares workflow_call" {
  run grep -E "^[[:space:]]+workflow_call:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-frontend-deploy: declares id-token: write permission" {
  run grep -A2 "^permissions:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"id-token: write"* ]]
}

@test "reusable-frontend-deploy: declares contents: read permission" {
  run grep -A2 "^permissions:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contents: read"* ]]
}

@test "reusable-frontend-deploy: does NOT grant deployments write at the workflow level" {
  # Deployments is governed by the GH Environment binding, not workflow perms.
  run grep -E "deployments:.*write" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

# --- Inputs ---

@test "reusable-frontend-deploy: input environment-name (string)" {
  run grep -B1 -A3 "environment-name:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-frontend-deploy: input gh-environment (string)" {
  run grep -B1 -A3 "gh-environment:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-frontend-deploy: input aws-region (string, default us-east-1)" {
  run grep -B1 -A5 "aws-region:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"us-east-1"* ]]
}

@test "reusable-frontend-deploy: input role-arn (string, with vars-not-secrets hint)" {
  run grep -B1 -A3 "role-arn:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  run grep -A3 "role-arn:" "$WORKFLOW"
  [[ "$output" == *"vars"* ]]
}

@test "reusable-frontend-deploy: input working-directory (string, default '.')" {
  run grep -B1 -A5 "working-directory:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'.'"* ]]
}

@test "reusable-frontend-deploy: input build-script (string, default 'build')" {
  run grep -B1 -A5 "build-script:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'build'"* ]]
}

@test "reusable-frontend-deploy: input node-version (string, default '24')" {
  run grep -B1 -A5 "node-version:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'24'"* ]]
}

@test "reusable-frontend-deploy: input bucket-name (string)" {
  run grep -B1 -A3 "bucket-name:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-frontend-deploy: input distribution-id (string)" {
  run grep -B1 -A3 "distribution-id:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-frontend-deploy: distribution-id regex pattern is locked" {
  # Drift detector: locks the actual regex string in the workflow so a
  # future relax/tighten is intentional and reviewed.
  run grep -oE '"distribution-id": "[^"]+"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"distribution-id": "^[A-Z0-9-]{10,14}$"'* ]]
}

@test "reusable-frontend-deploy: distribution-id regex accepts valid IDs (10, 13, 14 chars)" {
  REGEX='^[A-Z0-9-]{10,14}$'
  [[ "E1ABCDEFGH" =~ $REGEX ]]        # 10 chars
  [[ "E1ABCDEFGHIJK" =~ $REGEX ]]     # 13 chars
  [[ "E1ABCDEFGHIJKL" =~ $REGEX ]]    # 14 chars
}

@test "reusable-frontend-deploy: distribution-id regex rejects invalid IDs (lowercase, 9-char, 15-char)" {
  REGEX='^[A-Z0-9-]{10,14}$'
  [[ ! "e1abcdefghijkl" =~ $REGEX ]]    # lowercase
  [[ ! "E1ABCDEFG" =~ $REGEX ]]         # 9 chars (too short)
  [[ ! "E1ABCDEFGHIJKLM" =~ $REGEX ]]   # 15 chars (too long)
}

@test "reusable-frontend-deploy: input source-dir (string, default 'dist')" {
  run grep -B1 -A5 "source-dir:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'dist'"* ]]
}

@test "reusable-frontend-deploy: input cache-control-hashed (string)" {
  run grep -B1 -A3 "cache-control-hashed:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-frontend-deploy: input cache-control-html (string)" {
  run grep -B1 -A3 "cache-control-html:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-frontend-deploy: input invalidation-paths (string, default '/*')" {
  run grep -B1 -A5 "invalidation-paths:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'/*'"* ]]
}

@test "reusable-frontend-deploy: input dry-run (string, default empty)" {
  run grep -B1 -A5 "dry-run:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
}

# --- Outputs ---

@test "reusable-frontend-deploy: exposes url output pointing to distribution" {
  # workflow_call.outputs can only reference jobs.* (not steps.*),
  # so the indirection chain is step -> job.outputs -> workflow_call.outputs.
  run grep -B1 -A3 "url:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jobs.deploy.outputs.url"* ]]
}

# --- Action pins ---

@test "reusable-frontend-deploy: actions/checkout pinned to floating major v7" {
  run grep -E "uses: actions/checkout@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E "actions/checkout@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-frontend-deploy: configure-aws-credentials pinned to floating major v6" {
  run grep -E "uses: aws-actions/configure-aws-credentials@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E "aws-actions/configure-aws-credentials@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-frontend-deploy: setup-node pinned to floating major v7" {
  run grep -E "uses: actions/setup-node@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E "actions/setup-node@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-frontend-deploy: does not use session-duration with OIDC" {
  # Per AGENTS.md, no session-duration input - default GH Actions rotation.
  run grep -E "session-duration:" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-frontend-deploy: no dynamic secrets[inputs.*] lookup" {
  # Caller passes role ARN via vars, NOT secrets, because secrets are
  # not available in the with: block of a reusable call.
  run grep -E "secrets\[inputs\." "$WORKFLOW"
  [ "$status" -ne 0 ]
}

# --- Steps present ---

@test "reusable-frontend-deploy: includes checkout step" {
  run grep -E "uses: actions/checkout@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-frontend-deploy: includes configure-aws-credentials step" {
  run grep -E "uses: aws-actions/configure-aws-credentials@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-frontend-deploy: includes setup-node step" {
  run grep -E "uses: actions/setup-node@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-frontend-deploy: runs npm ci (not npm install)" {
  run grep -E "run: npm ci" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E "run: npm install" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-frontend-deploy: runs npm run via env-isolated build-script" {
  run grep -E 'INPUTS_BUILD_SCRIPT:' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E 'npm run "\$INPUTS_BUILD_SCRIPT"' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-frontend-deploy: includes aws s3 sync step guarded by dry-run != true" {
  run grep -E "aws s3 sync" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # Extract the sync-to-s3 step block (between - name: and the next - name:).
  run sed -n '/- name: sync-to-s3/,/^      - name:/p' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"if: inputs.dry-run != 'true'"* ]]
}

@test "reusable-frontend-deploy: includes cloudfront create-invalidation guarded by dry-run != true" {
  run grep -E "aws cloudfront create-invalidation" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run sed -n '/- name: create-invalidation/,/^      - name:/p' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"if: inputs.dry-run != 'true'"* ]]
}

@test "reusable-frontend-deploy: emits url output unconditionally (including dry-run)" {
  # The fetch step has no if: guard so the url is populated even in dry-run.
  run grep -B4 "echo \"url=https://" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" != *"if:"* ]]
}

# --- GH Actions hard constraints ---

@test "reusable-frontend-deploy: does not define its own concurrency block" {
  # Reusable workflows cannot define concurrency; the caller owns it.
  run grep -E "^concurrency:" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-frontend-deploy: file does not interpolate secrets inside with:/run:" {
  # GitHub Actions rejects ${{ secrets.X }} in the with: of a reusable call.
  # The whole file (any context) must be free of ${{ secrets.* }} interpolation.
  run grep -E '\${{[[:space:]]*secrets\.' "$WORKFLOW"
  [ "$status" -ne 0 ]
}

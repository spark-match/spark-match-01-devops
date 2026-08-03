#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# node-pkg-manager.bats - regression guards for real pkg-manager support
# (npm / pnpm / yarn / bun) across the four node-consuming reusable
# workflows in .github/workflows/. Each workflow must:
#   1. Accept all 4 pkg-managers via the validate-workflow-inputs enum.
#   2. Resolve the cache path per OS/pkg-manager in resolve-cache-key-tags.
#   3. Set up the package manager (corepack for pnpm/yarn; oven-sh/setup-bun
#      for bun; no-op for npm) in setup-pkg-manager.
#   4. Use the env-resolved PKG_INSTALL_CMD for install (no hardcoded npm ci).
#   5. Use the env-resolved PKG_RUN_CMD for run-* scripts (no hardcoded npm run).
#   6. Reference env vars written via GITHUB_ENV in kebab-case.

load 'helpers/common'

WORKFLOWS_DIR="$BATS_TEST_DIRNAME/../../.github/workflows"

WORKFLOWS=(
  "reusable-eslint.yml"
  "reusable-node-build.yml"
  "reusable-node-test.yml"
  "reusable-node-typecheck.yml"
)

@test "node workflows: enum accepts all 4 pkg-managers" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF '"pkg-manager": ["npm", "pnpm", "yarn", "bun"]' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: setup-pkg-manager step references corepack" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF 'name: setup-pkg-manager' "$WORKFLOWS_DIR/$wf"
    grep -qF 'corepack enable' "$WORKFLOWS_DIR/$wf"
    grep -qF 'corepack prepare' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: setup-bun-runtime step uses oven-sh/setup-bun@v2" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF "uses: oven-sh/setup-bun@v2" "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: setup-bun-runtime is conditional on pkg-manager == 'bun'" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF "if: inputs.pkg-manager == 'bun'" "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: cache path uses env.cache-path (no hardcoded ~/.npm)" {
  for wf in "${WORKFLOWS[@]}"; do
    ! grep -qF 'path: ~/.npm' "$WORKFLOWS_DIR/$wf"
    grep -qF 'path: ${{ env.cache-path }}' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: cache-path is exported from resolve-cache-key-tags" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF 'cache-path=' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: install step uses PKG_INSTALL_CMD (no hardcoded 'npm ci')" {
  for wf in "${WORKFLOWS[@]}"; do
    ! grep -qF 'run: npm ci' "$WORKFLOWS_DIR/$wf"
    grep -qF 'PKG_INSTALL_CMD' "$WORKFLOWS_DIR/$wf"
    grep -qF 'pkg-install-cmd' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: run-* step uses PKG_RUN_CMD (no hardcoded 'npm run')" {
  for wf in "${WORKFLOWS[@]}"; do
    ! grep -qF 'run: npm run' "$WORKFLOWS_DIR/$wf"
    grep -qF 'PKG_RUN_CMD' "$WORKFLOWS_DIR/$wf"
    grep -qF 'pkg-run-cmd' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: env vars use kebab-case (lower-os, env-name)" {
  for wf in "${WORKFLOWS[@]}"; do
    ! grep -qF 'env.lower_os' "$WORKFLOWS_DIR/$wf"
    ! grep -qF 'env.env_name' "$WORKFLOWS_DIR/$wf"
    grep -qF 'env.lower-os' "$WORKFLOWS_DIR/$wf"
    grep -qF 'env.env-name' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: setup-pkg-manager handles yarn v1 vs berry" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF 'YARN_VERSION="$(yarn --version)"' "$WORKFLOWS_DIR/$wf"
    grep -qF 'yarn install --frozen-lockfile' "$WORKFLOWS_DIR/$wf"
    grep -qF 'yarn install --immutable' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: pkg-install-cmd and pkg-run-cmd are exported to GITHUB_ENV" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF 'pkg-install-cmd=' "$WORKFLOWS_DIR/$wf"
    grep -qF 'pkg-run-cmd=' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: resolve-cache-key-tags handles all 12 OS/pkg-manager combos" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF 'linux:npm)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'linux:pnpm)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'linux:yarn)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'linux:bun)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'windows:npm)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'windows:pnpm)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'windows:yarn)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'windows:bun)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'macos:npm)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'macos:pnpm)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'macos:yarn)' "$WORKFLOWS_DIR/$wf"
    grep -qF 'macos:bun)' "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: error message in unsupported pkg-manager case is explicit" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF "::error::Unsupported pkg-manager" "$WORKFLOWS_DIR/$wf"
  done
}

@test "node workflows: error message in unsupported OS/pkg-manager combo is explicit" {
  for wf in "${WORKFLOWS[@]}"; do
    grep -qF "::error::Unsupported runner OS / pkg-manager combo" "$WORKFLOWS_DIR/$wf"
  done
}

@test "reusable-eslint: lint-script env-isolated under PKG_RUN_CMD" {
  grep -qF 'INPUTS_LINT_SCRIPT: ${{ inputs.lint-script }}' "$WORKFLOWS_DIR/reusable-eslint.yml"
  grep -qF 'PKG_RUN_CMD: ${{ env.pkg-run-cmd }}' "$WORKFLOWS_DIR/reusable-eslint.yml"
}

@test "reusable-node-build: build-script env-isolated under PKG_RUN_CMD" {
  grep -qF 'INPUTS_BUILD_SCRIPT: ${{ inputs.build-script }}' "$WORKFLOWS_DIR/reusable-node-build.yml"
  grep -qF 'PKG_RUN_CMD: ${{ env.pkg-run-cmd }}' "$WORKFLOWS_DIR/reusable-node-build.yml"
}

@test "reusable-node-build: pre-build-script env-isolated under PKG_RUN_CMD" {
  grep -qF 'INPUTS_PRE_BUILD_SCRIPT: ${{ inputs.pre-build-script }}' "$WORKFLOWS_DIR/reusable-node-build.yml"
}

@test "reusable-node-test: test-script env-isolated under PKG_RUN_CMD" {
  grep -qF 'INPUTS_TEST_SCRIPT: ${{ inputs.test-script }}' "$WORKFLOWS_DIR/reusable-node-test.yml"
}

@test "reusable-node-test: pre-test-script env-isolated under PKG_RUN_CMD" {
  grep -qF 'INPUTS_PRE_TEST_SCRIPT: ${{ inputs.pre-test-script }}' "$WORKFLOWS_DIR/reusable-node-test.yml"
}

@test "reusable-node-typecheck: typecheck-script env-isolated under PKG_RUN_CMD" {
  grep -qF 'INPUTS_TYPECHECK_SCRIPT: ${{ inputs.typecheck-script }}' "$WORKFLOWS_DIR/reusable-node-typecheck.yml"
}

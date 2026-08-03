#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reusable-ci-workflows.bats - regression guards for the cross-repo CI reusables
# =============================================================================
# Locks down the shape of:
#   - .github/workflows/reusable-commitlint.yml
#   - .github/workflows/reusable-release-please.yml
#   - the internal callers .github/workflows/commitlint.yml and
#     .github/workflows/release-please.yml (which must consume the
#     reusables so the catalog is auto-dogfooded)
#
# What this file protects against:
#   - Removing workflow_call from the reusable (would break cross-repo callers)
#   - Removing a documented input that callers depend on
#   - Forgetting to consume the reusable from the internal workflow (defeats
#     auto-dogfooding; CI could pass while the reusable shape drifts)
#   - Renaming an input or changing its type (silent breakage for consumers)
# =============================================================================

REUSABLE_COMMITLINT="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-commitlint.yml"
REUSABLE_RELEASE_PLEASE="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-release-please.yml"
INTERNAL_COMMITLINT="$BATS_TEST_DIRNAME/../../.github/workflows/commitlint.yml"
INTERNAL_RELEASE_PLEASE="$BATS_TEST_DIRNAME/../../.github/workflows/release-please.yml"

# ---------------------------------------------------------------------------
# reusable-commitlint.yml shape
# ---------------------------------------------------------------------------

@test "reusable-ci-workflows: reusable-commitlint.yml exists" {
  [ -f "$REUSABLE_COMMITLINT" ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml declares workflow_call" {
  run grep -E "^\s*workflow_call:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml exposes config-file input" {
  run grep -E "config-file:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "config-file:" "$REUSABLE_COMMITLINT"
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml exposes commit-depth input" {
  run grep -E "commit-depth:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "commit-depth:" "$REUSABLE_COMMITLINT"
  [[ "$output" == *"type: number"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml exposes help-url input" {
  run grep -E "help-url:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "help-url:" "$REUSABLE_COMMITLINT"
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml exposes skip-release-please input as boolean" {
  run grep -E "skip-release-please:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "skip-release-please:" "$REUSABLE_COMMITLINT"
  [[ "$output" == *"type: boolean"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml uses wagoid/commitlint-github-action@v6" {
  run grep -E "uses: wagoid/commitlint-github-action@v[0-9]+" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml uses actions/checkout@v7" {
  run grep -E "uses: actions/checkout@v[0-9]+" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml fails on errors" {
  run grep -E "failOnErrors: true" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml reads only contents" {
  run grep -A2 "^permissions:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contents: read"* ]]
  [[ "$output" != *"contents: write"* ]]
}

# ---------------------------------------------------------------------------
# reusable-release-please.yml shape
# ---------------------------------------------------------------------------

@test "reusable-ci-workflows: reusable-release-please.yml exists" {
  [ -f "$REUSABLE_RELEASE_PLEASE" ]
}

@test "reusable-ci-workflows: reusable-release-please.yml declares workflow_call" {
  run grep -E "^\s*workflow_call:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml exposes config-file input" {
  run grep -E "config-file:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "config-file:" "$REUSABLE_RELEASE_PLEASE"
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-ci-workflows: reusable-release-please.yml exposes manifest-file input" {
  run grep -E "manifest-file:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "manifest-file:" "$REUSABLE_RELEASE_PLEASE"
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-ci-workflows: reusable-release-please.yml exposes app-id-secret input" {
  run grep -E "app-id-secret:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "app-id-secret:" "$REUSABLE_RELEASE_PLEASE"
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-ci-workflows: reusable-release-please.yml exposes app-private-key-secret input" {
  run grep -E "app-private-key-secret:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "app-private-key-secret:" "$REUSABLE_RELEASE_PLEASE"
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-ci-workflows: reusable-release-please.yml uses create-github-app-token@v3" {
  run grep -E "uses: actions/create-github-app-token@v[0-9]+" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml uses release-please-action@v5" {
  run grep -E "uses: googleapis/release-please-action@v[0-9]+" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml needs contents write + pull-requests write" {
  run grep -A2 "^permissions:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contents: write"* ]]
  [[ "$output" == *"pull-requests: write"* ]]
}

# ---------------------------------------------------------------------------
# Auto-dogfooding: the internal workflows MUST consume the reusables
# ---------------------------------------------------------------------------

@test "reusable-ci-workflows: commitlint.yml consumes the reusable (auto-dogfooding)" {
  run grep -E "uses: \./.github/workflows/reusable-commitlint\.yml" "$INTERNAL_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: release-please.yml consumes the reusable (auto-dogfooding)" {
  run grep -E "uses: \./.github/workflows/reusable-release-please\.yml" "$INTERNAL_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: internal commitlint.yml does not duplicate wagoid step" {
  run grep -E "wagoid/commitlint-github-action" "$INTERNAL_COMMITLINT"
  [ "$status" -ne 0 ]
}

@test "reusable-ci-workflows: internal release-please.yml does not duplicate release-please step" {
  run grep -E "googleapis/release-please-action" "$INTERNAL_RELEASE_PLEASE"
  [ "$status" -ne 0 ]
}

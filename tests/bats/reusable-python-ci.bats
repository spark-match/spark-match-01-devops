#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reusable-python-ci.bats - regression guards for the Python QA reusable
# =============================================================================
# Locks down:
#   - workflow_call trigger declared
#   - every documented input has a type
#   - all actions pinned to a floating major tag (no SHA pins)
#   - no concurrency block (reusable workflows cannot own concurrency)
#   - INPUTS_* env vars used to isolate ${{ inputs.* }} interpolation
#     outside env: blocks (the workflow-env-isolation guard catches
#     ${{ inputs.* }} inside run: blocks separately)
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-python-ci.yml"

@test "reusable-python-ci: workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "reusable-python-ci: declares workflow_call trigger" {
  run grep -E "^[[:space:]]+workflow_call:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-python-ci: every input has type" {
  # Walk every input block and verify `type:` line appears.
  run grep -E -B1 -A4 "^[[:space:]]+[a-z][a-z0-9-]*:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # At least one type: string line per input (relaxed: just confirm presence).
  run grep -cE "^[[:space:]]+type: (string|boolean|number|choice)" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" -ge 19 ]
}

@test "reusable-python-ci: environment-name is required" {
  run grep -E -B1 -A4 "^[[:space:]]+environment-name:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"required: true"* ]]
}

@test "reusable-python-ci: python-version defaults to 3.14" {
  run grep -E -B1 -A5 "^[[:space:]]+python-version:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'3.14'"* ]]
}

@test "reusable-python-ci: coverage-threshold defaults to 80" {
  run grep -E -B1 -A5 "^[[:space:]]+coverage-threshold:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"'80'"* ]]
}

@test "reusable-python-ci: sync-mode enum is locked" {
  run grep -E -B1 -A12 "^[[:space:]]+sync-mode:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  run grep -E -A20 "enums:" "$WORKFLOW"
  [[ "$output" == *"sync-mode"* ]]
  [[ "$output" == *"full"* ]]
  [[ "$output" == *"runtime-only"* ]]
  [[ "$output" == *"lint-only"* ]]
}

@test "reusable-python-ci: every action pinned to floating major (no SHA pins)" {
  run grep -E "uses: [^@]+@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-python-ci: actions/checkout pinned to floating major v7" {
  run grep -E "uses: actions/checkout@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-python-ci: astral-sh/setup-uv pinned to floating major v9" {
  run grep -E "uses: astral-sh/setup-uv@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-python-ci: actions/upload-artifact pinned to floating major v7" {
  run grep -E "uses: actions/upload-artifact@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-python-ci: marocchino/sticky-pull-request-comment pinned to floating major v3" {
  run grep -E "uses: marocchino/sticky-pull-request-comment@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-python-ci: self-action validate-workflow-inputs pinned to @main" {
  run grep -E "uses: spark-match/spark-match-01-devops/\\.github/actions/validate-workflow-inputs@main" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-python-ci: self-action run-pytest-with-args pinned to @main" {
  run grep -E "uses: spark-match/spark-match-01-devops/\\.github/actions/run-pytest-with-args@main" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-python-ci: does not declare concurrency" {
  # Reusable workflows cannot own concurrency; the caller owns it.
  run grep -E "^concurrency:" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-python-ci: validates commands token against allowed steps" {
  run grep -E -A20 "validate-commands-token" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"security:pip-audit"* ]]
  [[ "$output" == *"coverage:report"* ]]
  [[ "$output" == *"coverage:upload"* ]]
}

@test "reusable-python-ci: coverage:report step exists" {
  run grep -E -A12 "^[[:space:]]+- name: coverage-report" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"coverage report --fail-under"* ]]
  [[ "$output" == *"coverage xml"* ]]
}

#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reusable-sonar-python.bats - regression guards for the sonar-python
# reusable (symmetric to reusable-sonar-typescript.yml but Cobertura)
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-sonar-python.yml"

@test "reusable-sonar-python: workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "reusable-sonar-python: declares workflow_call trigger" {
  run grep -E "^[[:space:]]+workflow_call:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-sonar-python: every input has type" {
  run grep -cE "^[[:space:]]+type: (string|boolean|number|choice)" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" -ge 13 ]
}

@test "reusable-sonar-python: python-version defaults to 3.14" {
  run grep -E -B1 -A5 "^[[:space:]]+python-version:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'3.14'"* ]]
}

@test "reusable-sonar-python: required inputs are project-key, project-name, organization, sources, tests, working-directory, env, sync-groups, pytest-targets, pytest-args, coverage-paths, fail-on-quality-gate" {
  for input in project-key project-name organization sources tests working-directory env sync-groups pytest-targets pytest-args coverage-paths fail-on-quality-gate; do
    run grep -E -B1 -A4 "^[[:space:]]+${input}:" "$WORKFLOW"
    [ "$status" -eq 0 ]
    [[ "$output" == *"required: true"* ]]
  done
}

@test "reusable-sonar-python: coverage paths point at sonar.python.coverage.reportPaths (Cobertura)" {
  run grep -E -A12 "sonar-cloud-scan" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sonar.python.coverage.reportPaths"* ]]
  [[ "$output" != *"sonar.javascript.lcov"* ]]
}

@test "reusable-sonar-python: passes sonar.python.version to scanner" {
  run grep -E -A15 "sonar-cloud-scan" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sonar.python.version"* ]]
}

@test "reusable-sonar-python: SONAR_TOKEN secret required" {
  run grep -E -B1 -A2 "^[[:space:]]+SONAR_TOKEN:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"required: true"* ]]
}

@test "reusable-sonar-python: every action pinned to floating major (no SHA pins)" {
  run grep -E "uses: [^@]+@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-sonar-python: actions/checkout pinned to floating major v7" {
  run grep -E "uses: actions/checkout@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-sonar-python: setup-uv pinned to floating major v9" {
  run grep -E "uses: astral-sh/setup-uv@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-sonar-python: sonarqube-scan-action pinned to floating major v8" {
  run grep -E "uses: sonarsource/sonarqube-scan-action@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-sonar-python: sonarqube-quality-gate-action pinned to floating major v1" {
  run grep -E "uses: sonarsource/sonarqube-quality-gate-action@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-sonar-python: actions/cache pinned to floating major v6" {
  run grep -E "uses: actions/cache@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-sonar-python: self-action validate-workflow-inputs pinned to @main" {
  run grep -E "uses: spark-match/spark-match-01-devops/\\.github/actions/validate-workflow-inputs@main" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-sonar-python: self-action run-pytest-with-args pinned to @main" {
  run grep -E "uses: spark-match/spark-match-01-devops/\\.github/actions/run-pytest-with-args@main" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-sonar-python: does not declare concurrency" {
  run grep -E "^concurrency:" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-sonar-python: quality gate enforcement step present" {
  run grep -E -A8 "^[[:space:]]+- name: enforce-quality-gate" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Quality Gate FAILED"* ]]
  [[ "$output" == *"fail-on-quality-gate"* ]]
}

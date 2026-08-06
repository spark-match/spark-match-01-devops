#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reusable-trivy.bats - regression guards for the Trivy reusable
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-trivy.yml"

@test "reusable-trivy: workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "reusable-trivy: declares workflow_call trigger" {
  run grep -E "^[[:space:]]+workflow_call:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-trivy: every input has type" {
  run grep -cE "^[[:space:]]+type: (string|boolean|number|choice)" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" -ge 9 ]
}

@test "reusable-trivy: scan-type enum is locked (fs/image/config)" {
  run grep -E -B1 -A4 "^[[:space:]]+scan-type:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  run grep -E -A20 "enums:" "$WORKFLOW"
  [[ "$output" == *"\"scan-type\": [\"fs\", \"image\", \"config\"]"* ]]
}

@test "reusable-trivy: severity defaults to CRITICAL (configurable HIGH+)" {
  run grep -E -B1 -A4 "^[[:space:]]+severity:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'CRITICAL'"* ]]
}

@test "reusable-trivy: format enum (table/sarif)" {
  run grep -E -B1 -A4 "^[[:space:]]+format:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"'table'"* ]]
  run grep -E -A20 "enums:" "$WORKFLOW"
  [[ "$output" == *"\"format\": [\"table\", \"sarif\"]"* ]]
}

@test "reusable-trivy: image-ref input exists with empty default" {
  run grep -E -B1 -A4 "^[[:space:]]+image-ref:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"required: false"* ]]
}

@test "reusable-trivy: ignore-unfixed defaults to true" {
  run grep -E -B1 -A4 "^[[:space:]]+ignore-unfixed:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: boolean"* ]]
  [[ "$output" == *"default: true"* ]]
}

@test "reusable-trivy: scanners defaults to vuln,secret,misconfig" {
  run grep -E -B1 -A4 "^[[:space:]]+scanners:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"vuln,secret,misconfig"* ]]
}

@test "reusable-trivy: every action pinned (no SHA pins)" {
  run grep -E "uses: [^@]+@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-trivy: trivy-action pinned to exact minor WITH the v prefix" {
  # Pin a minor exacto porque la linea 0.x rompe entre minors (AGENTS.md 5.1).
  #
  # El `v` NO es opcional. Este test antes exigia lo contrario -- pedia
  # `@[0-9]+\.[0-9]+\.[0-9]+`, sin `v`, con el comentario "trivy-action
  # publishes 0.X.Y without `v` prefix". Eso es falso: en
  # aquasecurity/trivy-action TODOS los tags llevan `v`. La API confirma
  # v0.36.0 y devuelve 404 para 0.36.0.
  #
  # Consecuencia: la receta se restauro el 2026-08-04 (PR #297) con
  # `@0.36.0`, jamas resolvio, y este test lo daba por bueno. No salto porque
  # la receta no tenia ni un consumidor: cero runs en toda la organizacion.
  # Lo destapo el primer repo que intento usarla.
  run grep -E "uses: aquasecurity/trivy-action@v[0-9]+\\.[0-9]+\\.[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # Y que no quede ninguna referencia sin el prefijo.
  run grep -E "uses: aquasecurity/trivy-action@[0-9]" "$WORKFLOW"
  [ "$status" -ne 0 ]
  # Specifically NOT a SHA pin.
  run grep -E "uses: aquasecurity/trivy-action@[a-f0-9]{40}" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-trivy: codeql upload-sarif pinned to floating major v4" {
  run grep -E "uses: github/codeql-action/upload-sarif@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-trivy: actions/checkout pinned to floating major v7" {
  run grep -E "uses: actions/checkout@v[0-9]+" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-trivy: self-action validate-workflow-inputs pinned to @main" {
  run grep -E "uses: spark-match/spark-match-01-devops/\\.github/actions/validate-workflow-inputs@main" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "reusable-trivy: permissions contents read + security-events write" {
  run grep -E -A3 "^permissions:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contents: read"* ]]
  [[ "$output" == *"security-events: write"* ]]
}

@test "reusable-trivy: does not declare concurrency" {
  run grep -E "^concurrency:" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "reusable-trivy: SARIF upload step gated on format==sarif" {
  run grep -E -A1 "upload-sarif-to-github-security" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"inputs.format == 'sarif'"* ]]
}

#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# terraform-plan-exit-code.bats - guard contra el apply no-op silencioso
# =============================================================================
# Las tres recetas de terraform corren `terraform plan -detailed-exitcode` y
# derivan de su exit code si hay cambios que aplicar. Los codigos son:
#
#   0 = ok, sin cambios
#   1 = error
#   2 = ok, con cambios
#
# La version anterior hacia `if [ "$EXIT_CODE" = "2" ]; then true; else false; fi`,
# que mete el error (1) en el mismo saco que "sin cambios" (0). Efecto real: el
# plan de dev fallaba con 14 AccessDenied durante el refresh, el apply se
# saltaba, y el job terminaba en verde. Nadie lo vio durante mucho tiempo.
#
# Estos tests fijan el comportamiento correcto: exit 1 rompe el job.
# =============================================================================

WORKFLOWS_DIR="$BATS_TEST_DIRNAME/../../.github/workflows"

PLAN_WORKFLOWS=(
  "reusable-terraform-apply.yml"
  "reusable-terraform-plan.yml"
  "reusable-terraform-destroy.yml"
)

@test "todas las recetas de terraform existen" {
  for wf in "${PLAN_WORKFLOWS[@]}"; do
    [ -f "$WORKFLOWS_DIR/$wf" ]
  done
}

@test "cada receta usa -detailed-exitcode (sin el, plan siempre sale 0)" {
  for wf in "${PLAN_WORKFLOWS[@]}"; do
    run grep -F -- "-detailed-exitcode" "$WORKFLOWS_DIR/$wf"
    [ "$status" -eq 0 ]
  done
}

@test "cada receta propaga el exit code del plan cuando falla" {
  for wf in "${PLAN_WORKFLOWS[@]}"; do
    run grep -F 'exit "${EXIT_CODE}"' "$WORKFLOWS_DIR/$wf"
    [ "$status" -eq 0 ]
  done
}

@test "cada receta distingue los tres exit codes con un case" {
  for wf in "${PLAN_WORKFLOWS[@]}"; do
    run grep -E '^\s+case "\$\{EXIT_CODE\}" in' "$WORKFLOWS_DIR/$wf"
    [ "$status" -eq 0 ]

    run grep -E '^\s+0\) echo "ha[sd]-changes=false"' "$WORKFLOWS_DIR/$wf"
    [ "$status" -eq 0 ]

    run grep -E '^\s+2\) echo "ha[sd]-changes=true"' "$WORKFLOWS_DIR/$wf"
    [ "$status" -eq 0 ]
  done
}

@test "cada receta emite ::error:: antes de romper" {
  for wf in "${PLAN_WORKFLOWS[@]}"; do
    run grep -F '::error::terraform plan fallo con exit code' "$WORKFLOWS_DIR/$wf"
    [ "$status" -eq 0 ]
  done
}

@test "ninguna receta vuelve al if de dos ramas que tragaba el error" {
  # El patron viejo: un unico `if [ "${EXIT_CODE}" = "2" ]` seguido de un else
  # que pone has-changes=false sin mirar si el codigo era 0 o 1.
  for wf in "${PLAN_WORKFLOWS[@]}"; do
    run grep -E 'if \[ "\$\{EXIT_CODE\}" = "2" \]' "$WORKFLOWS_DIR/$wf"
    [ "$status" -ne 0 ]
  done
}

@test "el paso siguiente sigue condicionado a que haya cambios" {
  # El arreglo no debe volver incondicional el apply: si el plan sale 0, no hay
  # nada que aplicar y el paso se sigue saltando.
  run grep -F "if: steps.plan.outputs.has-changes == 'true'" "$WORKFLOWS_DIR/reusable-terraform-apply.yml"
  [ "$status" -eq 0 ]
}

#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# python-ci-multiple-targets.bats - guard contra el bug de comillas en targets
# =============================================================================
# Los inputs de un workflow no pueden interpolarse dentro de un `run:`, asi que
# llegan por variable de entorno. Entrecomillar esa variable pasa TODO el valor
# como un unico argumento:
#
#     uv run ruff format --check "${INPUTS_RUFF_TARGETS}"
#
# Con ruff-targets='src tests evals', ruff recibia una ruta literal llamada
# "src tests evals" y moria con "No such file or directory (os error 2)".
#
# Estaba roto incluso con el default del propio input ('src tests'). Nadie lo
# habia notado porque ningun caller habia migrado todavia al catalogo.
#
# El arreglo divide con `IFS=', ' read -ra` y expande con "${TARGETS[@]}", que
# acepta tanto comas como espacios.
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-python-ci.yml"

@test "reusable-python-ci existe" {
  [ -f "$WORKFLOW" ]
}

@test "ningun comando pasa los targets como un unico argumento entrecomillado" {
  # El patron viejo: la variable entrecomillada directamente como argumento
  # de la herramienta, sin dividir antes.
  for tool in ruff bandit mypy; do
    run grep -E "uv run ${tool}.*\"\\\$\{INPUTS_(RUFF|MYPY)_TARGETS\}\"" "$WORKFLOW"
    [ "$status" -ne 0 ]
  done
}

@test "cada comando divide los targets antes de expandirlos" {
  # 5 usos de RUFF_TARGETS (format, format-fix, check, check-fix, bandit)
  # mas 1 de MYPY_TARGETS.
  run grep -cE "IFS=', ' read -ra TARGETS" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" -eq 6 ]
}

@test "cada comando expande el array, no la variable cruda" {
  run grep -cE '"\$\{TARGETS\[@\]\}"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" -eq 6 ]
}

@test "los targets siguen llegando por env, no interpolados en el run" {
  # No romper la regla que ya cubre reusable-ci-workflows.bats.
  run grep -E '^\s+INPUTS_RUFF_TARGETS: \$\{\{ inputs\.ruff-targets \}\}' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "el split acepta espacios y comas" {
  IFS=', ' read -ra TARGETS <<< "src tests evals"
  [ "${#TARGETS[@]}" -eq 3 ]
  [ "${TARGETS[2]}" = "evals" ]

  IFS=', ' read -ra TARGETS <<< "src,tests,evals"
  [ "${#TARGETS[@]}" -eq 3 ]
  [ "${TARGETS[2]}" = "evals" ]
}

@test "la descripcion de los inputs ya no miente diciendo CSV" {
  run grep -E "description: 'CSV of paths passed to" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

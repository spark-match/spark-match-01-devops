#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reconciler-drift-is-visible.bats
# =============================================================================
# Cuando `configure-repo-rulesets.sh` detecta drift tiene que decir CUAL, no
# solo que lo hay.
#
# POR QUE. `canonical_diff()` normaliza los dos payloads y los compara. Hasta
# 2026-09-06 emitia `in-sync` o `drift` y tiraba el diff que acababa de
# calcular. Ese dia --check daba `drift` en los 9 repositorios de la
# organizacion y la unica diferencia era un campo que GitHub habia anadido por
# su lado y que el payload deseado no construye:
#
#     "require_extra_approval_for_unattributed_changes": true
#
# El PUT de rulesets reemplaza las reglas enteras, asi que un --apply lo habria
# devuelto a su default y habria APAGADO esa proteccion en los 9 repositorios a
# la vez. Con la salida anterior no habia forma de saberlo: nueve `drift`
# identicos, y el unico camino que la herramienta ofrecia para resolverlos era
# justamente el --apply que causaba el dano.
#
# Un reconciliador que sabe que algo cambio y no dice que es empuja al operador
# a aplicar a ciegas. Estos tests fijan lo contrario.
#
# EL CONTRATO QUE NO SE PUEDE ROMPER. El caller hace
# `[[ "$diff" == "in-sync" ]]` sobre el stdout de la funcion. Por eso el diff
# va a stderr y stdout sigue siendo exactamente una de las dos palabras. El
# ultimo test de este fichero es el que guarda esa separacion.
# =============================================================================

load 'helpers/reconciler'

setup() {
  load 'helpers/reconciler'
  write_default_manifest
  cd "$BATS_TEST_TMPDIR"
  mkdir -p fixtures
  echo '{"id": 12345}' > fixtures/team-devops
  echo '[]' > fixtures/rulesets-list.json
}

# Construye el payload que el script considera deseado para spark-match-foo y
# lo deja como ruleset vivo (id 99), con la mutacion que le pase el caller
# aplicada encima via jq. Asi el unico drift es el que el test provoca.
publicar_ruleset_vivo() {
  local mutacion="$1"
  local fn_body
  fn_body=$(sed -n '/^build_desired_payload()/,/^}$/p' "$SCRIPT")
  eval "$fn_body"
  export MANIFEST="$BATS_TEST_TMPDIR/fixtures/manifest.json"

  local payload
  payload=$(build_desired_payload "spark-match-foo" "12345")
  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  echo "$payload" | jq "$mutacion" > fixtures/rule-99.json
}

@test "drift: --check nombra el campo que sobra en GitHub, no solo la palabra drift" {
  # Reproduce la forma exacta del incidente: un parametro que vive en el
  # ruleset y que el manifiesto no construye.
  publicar_ruleset_vivo '
    .rules |= map(
      if .type == "pull_request"
      then .parameters.require_extra_approval_for_unattributed_changes = true
      else . end
    )'

  run bash "$SCRIPT" --check \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
    --repos spark-match-foo

  [ "$status" -eq 1 ]
  [[ "$output" == *"drift"* ]]
  [[ "$output" == *"require_extra_approval_for_unattributed_changes"* ]]
}

@test "drift: --check nombra el campo que falta en GitHub" {
  # La direccion contraria: el manifiesto pide algo que el ruleset no tiene.
  # Sin el diff, este caso y el anterior son indistinguibles para el operador.
  publicar_ruleset_vivo '
    .rules |= map(
      if .type == "pull_request"
      then .parameters.required_approving_review_count = 7
      else . end
    )'

  run bash "$SCRIPT" --check \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
    --repos spark-match-foo

  [ "$status" -eq 1 ]
  [[ "$output" == *"required_approving_review_count"* ]]
}

@test "drift: la linea del diff dice de que repositorio habla" {
  # --check recorre varios repos y los diffs salen intercalados; sin el nombre
  # no se sabe cual es cual.
  publicar_ruleset_vivo '
    .rules |= map(
      if .type == "pull_request"
      then .parameters.require_extra_approval_for_unattributed_changes = true
      else . end
    )'

  run bash "$SCRIPT" --check \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
    --repos spark-match-foo

  [[ "$output" == *"[DIFF] spark-match-foo"* ]]
}

@test "in-sync: un repositorio sin drift no imprime ningun diff" {
  # El guard del guard por el lado del ruido: si el diff se imprimiera siempre,
  # los tres tests de arriba pasarian sin que la deteccion funcione.
  publicar_ruleset_vivo '.'

  run bash "$SCRIPT" --check \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
    --repos spark-match-foo

  [ "$status" -eq 0 ]
  [[ "$output" == *"in-sync"* ]]
  [[ "$output" != *"[DIFF]"* ]]
}

@test "contrato: canonical_diff emite por stdout exactamente in-sync o drift" {
  # El caller hace `[[ "$diff" == "in-sync" ]]` sobre este stdout. Si el diff
  # se colara por ahi, la comparacion fallaria siempre y TODO repositorio
  # saldria en drift -- incluidos los que estan bien.
  fn_body=$(sed -n '/^canonical_diff()/,/^}$/p' "$SCRIPT")
  eval "$fn_body"

  local base='{"bypass_actors":[],"conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":1}}]}'
  local otro='{"bypass_actors":[],"conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":2}}]}'

  # Iguales -> stdout es la palabra exacta, sin adornos.
  local salida
  salida=$(canonical_diff "$base" "$base" "spark-match-foo" 2>/dev/null)
  [ "$salida" = "in-sync" ]

  # Distintos -> stdout sigue siendo una sola palabra...
  salida=$(canonical_diff "$base" "$otro" "spark-match-foo" 2>/dev/null)
  [ "$salida" = "drift" ]

  # ...y el diff esta, pero en stderr.
  local err
  err=$(canonical_diff "$base" "$otro" "spark-match-foo" 2>&1 >/dev/null)
  [[ "$err" == *"required_approving_review_count"* ]]
  [[ "$err" == *"spark-match-foo"* ]]
}

@test "--json: el diff no contamina el bloque JSON de salida" {
  # Guard de la regresion que introdujo la primera version de este cambio. El
  # diff sale por stderr, pero bats mezcla stdout y stderr en $output y con
  # --json la salida es un `jq -s` indentado. La primera version indentaba las
  # lineas del diff sin prefijo, se colaban dentro del JSON y lo volvian
  # improsable: reventaron dos tests de reconciler-apply.bats que no tenian
  # nada que ver con este cambio.
  #
  # Por eso CADA linea del diff lleva [DIFF], igual que [INFO]/[WARN]/[ERR]:
  # es lo que permite a json_output() filtrarlas por linea.
  publicar_ruleset_vivo '
    .rules |= map(
      if .type == "pull_request"
      then .parameters.require_extra_approval_for_unattributed_changes = true
      else . end
    )'

  run bash "$SCRIPT" --check --json     --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json"     --repos spark-match-foo

  # El diff esta en la salida combinada...
  [[ "$output" == *"require_extra_approval_for_unattributed_changes"* ]]

  # ...y aun asi el JSON se parsea y dice lo que tiene que decir.
  local json
  json=$(json_output)
  echo "$json" | jq -e '.[] | select(.repo == "spark-match-foo") | .state == "drift"' >/dev/null
}

@test "--json: toda linea del diff lleva el prefijo [DIFF]" {
  # El filtro de json_output() es por prefijo de linea. Si una sola linea del
  # diff saliera sin el, se colaria en el JSON. Esto lo comprueba directamente
  # sobre stderr, sin depender de que el parseo de arriba falle por casualidad.
  fn_body=$(sed -n '/^canonical_diff()/,/^}$/p' "$SCRIPT")
  eval "$fn_body"

  local base='{"bypass_actors":[],"conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":1}}]}'
  local otro='{"bypass_actors":[],"conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":2}}]}'

  local err
  err=$(canonical_diff "$base" "$otro" "spark-match-foo" 2>&1 >/dev/null)

  [ -n "$err" ]
  while IFS= read -r linea; do
    [[ -z "$linea" ]] && continue
    [[ "$linea" == "[DIFF]"* ]]
  done <<<"$err"
}

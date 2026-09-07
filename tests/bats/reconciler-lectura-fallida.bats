#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reconciler-lectura-fallida.bats
# =============================================================================
# "No pude leer" NO es "no hay nada", y tampoco es "hay drift".
#
# EL INCIDENTE. El 2026-09-07, en la primera ejecucion de governance-drift.yml,
# el reconciliador reporto drift en los NUEVE repositorios de la organizacion,
# con un diff que era el payload deseado entero. No habia drift: la GitHub App
# no tenia permiso de lectura sobre `administration` ni sobre `members`, y el
# estado actual llegaba vacio en los nueve.
#
# La causa era un patron repetido en las cuatro lecturas del script:
#
#     gh api ... 2>/dev/null || echo <valor benigno>
#
# Cada valor elegido era el mas enganoso posible para su sitio:
#
#   `|| echo ""`   al resolver un equipo   El id pasaba a ser el CUERPO del 404.
#                                          `gh api --jq` escribe el error por
#                                          stdout, y el `|| echo ""` no descarta
#                                          lo ya capturado, asi que el guard de
#                                          "id vacio" no saltaba nunca.
#   `|| echo "[]"` al listar rulesets      "Este repositorio no tiene ninguno".
#                                          Con --apply eso es un POST encima del
#                                          ruleset que si existe.
#   `|| echo "{}"` al leer el detalle      Estado actual vacio -> drift del
#                                          payload entero.
#
# El de la lista es el peor de los tres: convierte un fallo de LECTURA en una
# ESCRITURA. Por eso estos tests miran sobre todo que un repo con la lectura
# rota salga como `failed` y no como algo que invite a reconciliar.
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

# Deja un ruleset "vivo" (id 99) que coincide con el deseado, para que sin
# fallos de lectura el repo salga in-sync. Asi cualquier estado distinto en los
# tests de abajo viene del fallo que el test provoca, no de un drift de fondo.
publicar_ruleset_en_sync() {
  local fn_body
  fn_body=$(sed -n '/^build_desired_payload()/,/^}$/p' "$SCRIPT")
  eval "$fn_body"
  export MANIFEST="$BATS_TEST_TMPDIR/fixtures/manifest.json"
  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  build_desired_payload "spark-match-foo" "12345" > fixtures/rule-99.json
}

@test "linea base: sin fallos de lectura el repo sale in-sync" {
  # El guard del guard. Si esto no pasara, los tests de abajo podrian estar
  # viendo un `failed` que no tiene nada que ver con la lectura.
  publicar_ruleset_en_sync
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"in-sync"* ]]
}

@test "listar rulesets falla -> failed, NO 'no existe'" {
  # El caso que con --apply acabaria creando un ruleset duplicado.
  publicar_ruleset_en_sync
  touch fixtures/rulesets-list-fail

  # La tabla solo imprime repo/estado/id; el motivo vive en la salida JSON.
  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 1 ]
  [[ "$output" != *"in-sync"* ]]
  local json
  json=$(json_output)
  echo "$json" | jq -e '.[] | select(.repo == "spark-match-foo") | .state == "failed"' >/dev/null
  echo "$json" | jq -e '.[] | select(.repo == "spark-match-foo") | .reason == "read-failed"' >/dev/null
}

@test "listar rulesets falla -> el motivo de la API sale en el log" {
  publicar_ruleset_en_sync
  touch fixtures/rulesets-list-fail

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  # Sin el mensaje de la API, el operador ve "failed" y no sabe si es permisos,
  # red, o un repositorio que ya no existe.
  [[ "$output" == *"Not Found"* ]]
}

@test "leer el detalle falla -> failed, NO drift" {
  # El caso exacto del 2026-09-07: el ruleset aparece en la lista y su detalle
  # no se puede leer.
  publicar_ruleset_en_sync
  touch fixtures/rule-detail-fail

  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 1 ]
  # Lo que NO puede pasar: presentarlo como drift, que invita a un --apply.
  [[ "$output" != *"drift"* ]]
  local json
  json=$(json_output)
  echo "$json" | jq -e '.[] | select(.repo == "spark-match-foo") | .reason == "read-failed"' >/dev/null
}

@test "leer el detalle falla -> no se emite ningun diff" {
  # El sintoma visible del incidente era un [DIFF] con el payload entero.
  publicar_ruleset_en_sync
  touch fixtures/rule-detail-fail

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [[ "$output" != *"[DIFF]"* ]]
}

@test "un equipo que no resuelve nunca se propaga como id" {
  # El bug del cuerpo del 404 colandose como team id. Hoy es inocuo porque
  # team_id no se usa en el payload; deja de serlo en cuanto required_reviewers
  # se pueble, y entonces el blob entraria como reviewer_id.
  rm -f fixtures/team-devops
  publicar_ruleset_en_sync

  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 1 ]
  local json
  json=$(json_output)
  echo "$json" | jq -e '.[] | select(.repo == "spark-match-foo") | .reason == "team-not-found"' >/dev/null
  # Y el sintoma concreto del bug: el log llegaba a imprimir
  # "team 'devops' -> id {"message":"Not Found"...}".
  [[ "$output" != *"-> id {"* ]]
}

@test "--apply no escribe nada en un repositorio cuya lectura fallo" {
  # La consecuencia que de verdad importa. gh.log registra toda llamada, asi
  # que se puede afirmar la AUSENCIA de POST y PUT.
  publicar_ruleset_en_sync
  touch fixtures/rulesets-list-fail

  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -ne 0 ]
  if [ -f "$BATS_TEST_TMPDIR/gh.log" ]; then
    run grep -E '^gh api .*(-X POST|-X PUT)' "$BATS_TEST_TMPDIR/gh.log"
    [ "$status" -ne 0 ]
  fi
}

# ---------------------------------------------------------------------------
# Comparar tampoco es un veredicto si no se pudo hacer
# ---------------------------------------------------------------------------
# Segundo disfraz del mismo incidente. Con los permisos ya concedidos, la
# respuesta de la API seguia sin traer `bypass_actors`: GitHub omite ese campo
# para un token que no puede gestionar el bypass. La normalizacion hacia
# `.bypass_actors |= map(...)` sobre null, jq moria con "Cannot iterate over
# null", el error se iba por stderr y `cur_norm` quedaba VACIO -- con lo que el
# diff volvia a salir como el payload entero sobre los nueve repositorios.
# ---------------------------------------------------------------------------

@test "bypass_actors ausente: no revienta ni inventa drift" {
  # El caso real del token de la GitHub App.
  publicar_ruleset_en_sync
  jq 'del(.bypass_actors)' fixtures/rule-99.json > fixtures/tmp.json
  mv fixtures/tmp.json fixtures/rule-99.json

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"in-sync"* ]]
  [[ "$output" != *"[DIFF]"* ]]
}

@test "bypass_actors ausente: se avisa de que ese campo no se comparo" {
  # Cobertura parcial dicha en voz alta. Sin este aviso, --check saldria verde
  # sin que nadie sepa que un cambio en quien puede saltarse el ruleset no se
  # estaba mirando.
  publicar_ruleset_en_sync
  jq 'del(.bypass_actors)' fixtures/rule-99.json > fixtures/tmp.json
  mv fixtures/tmp.json fixtures/rule-99.json

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [[ "$output" == *"bypass_actors"* ]]
  [[ "$output" == *"FUERA de la comparacion"* ]]
}

@test "un payload que no se puede normalizar sale como compare-failed" {
  # Cualquier otra forma inesperada. Lo que no puede pasar es que una
  # normalizacion rota se lea como in-sync, que es lo que ocurriria si las dos
  # cadenas salieran vacias.
  publicar_ruleset_en_sync
  echo '{"rules": "esto-no-es-un-array", "conditions": {}}' > fixtures/rule-99.json

  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 1 ]
  [[ "$output" != *"in-sync"* ]]
  local json
  json=$(json_output)
  echo "$json" | jq -e '.[] | select(.repo == "spark-match-foo") | .reason == "compare-failed"' >/dev/null
}

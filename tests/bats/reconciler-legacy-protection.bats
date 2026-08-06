#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reconciler-legacy-protection.bats - deteccion de branch protection CLASICA
# =============================================================================
# Los rulesets y la branch protection clasica son dos superficies distintas de
# la API. Hasta 2026-08-06 el reconciliador solo miraba /rulesets, asi que
# --check daba verde en repositorios que corrian las dos capas a la vez.
#
# Tres de nueve repos las tenian, con enforce_admins=true, y eso anula el
# bypass del ruleset: ni un admin de la organizacion puede mergear, ni por CLI
# ni por REST API. El sintoma era "Repository rule violations found / Waiting
# on code owner review" en un repo cuyo ruleset por si solo lo permitiria.
#
# Estos tests cubren que se detecte siempre y que solo se borre cuando alguien
# lo pide explicitamente.
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

# Payload recortado de la respuesta real de la API para spark-match-07-article.
write_legacy_protection() {
  cat > fixtures/legacy-protection.json <<'EOF'
{
  "enforce_admins": { "enabled": true },
  "required_pull_request_reviews": {
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  }
}
EOF
}

# -----------------------------------------------------------------------------
# Deteccion
# -----------------------------------------------------------------------------

@test "legacy: sin proteccion clasica no aparece nada (404 es el estado deseado)" {
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  [[ "$output" != *"legacy-protection"* ]]
}

@test "legacy: con proteccion clasica sale como drift en --check" {
  write_legacy_protection

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  [[ "$output" == *"legacy-protection"* ]]
  # drift => exit 1, que es lo que hace fallar un CI de governance.
  [ "$status" -eq 1 ]
}

@test "legacy: el aviso nombra enforce_admins, que es lo que rompe el bypass" {
  write_legacy_protection

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  [[ "$output" == *"enforce_admins=true"* ]]
}

@test "legacy: el JSON de salida lleva branch y enforce_admins" {
  write_legacy_protection

  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  json_output | jq -e '.[] | select(.state == "legacy-protection") | .enforce_admins == true' >/dev/null
  json_output | jq -e '.[] | select(.state == "legacy-protection") | .branch == "main"' >/dev/null
}

@test "legacy: usa la rama por defecto real, no asume main" {
  write_legacy_protection
  echo "trunk" > fixtures/default-branch

  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  json_output | jq -e '.[] | select(.state == "legacy-protection") | .branch == "trunk"' >/dev/null
}

# -----------------------------------------------------------------------------
# Borrado: solo bajo peticion explicita
# -----------------------------------------------------------------------------

@test "legacy: --apply SIN el flag no borra nada" {
  write_legacy_protection

  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  # Mismo criterio que --prune-unexpected: no se destruye lo que no creamos.
  ! grep -qE "DELETE .*branches/.*/protection" "$BATS_TEST_TMPDIR/gh.log"
  [[ "$output" == *"legacy-protection"* ]]
}

@test "legacy: --prune-legacy-protection con --apply si la borra" {
  write_legacy_protection

  run bash "$SCRIPT" --apply --prune-legacy-protection \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  grep -qE "DELETE repos/spark-match/spark-match-foo/branches/main/protection" "$BATS_TEST_TMPDIR/gh.log"
  [[ "$output" == *"legacy-protection-removed"* ]]
}

@test "legacy: --dry-run no borra aunque se pase el flag" {
  write_legacy_protection

  run bash "$SCRIPT" --apply --dry-run --prune-legacy-protection \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  ! grep -qE "DELETE .*branches/.*/protection" "$BATS_TEST_TMPDIR/gh.log"
}

@test "legacy: --check nunca borra, ni con el flag" {
  write_legacy_protection

  run bash "$SCRIPT" --check --prune-legacy-protection \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  ! grep -qE "DELETE .*branches/.*/protection" "$BATS_TEST_TMPDIR/gh.log"
}

@test "legacy: un DELETE rechazado es fallo, no exito silencioso" {
  write_legacy_protection
  touch fixtures/legacy-delete-rejected

  run bash "$SCRIPT" --apply --prune-legacy-protection --json \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  [ "$status" -eq 1 ]
  # La tabla solo imprime `state`; el motivo va en `reason`, igual que el resto
  # de fallos del script. Por eso se comprueba contra el JSON.
  json_output | jq -e '.[] | select(.reason == "legacy-protection-delete-failed")' >/dev/null
}

# -----------------------------------------------------------------------------
# Interaccion con --strict
# -----------------------------------------------------------------------------

@test "legacy: con --strict la proteccion clasica es fallo duro" {
  write_legacy_protection

  run bash "$SCRIPT" --apply --strict \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  # Sin --strict, --apply solo avisa. Con --strict, log_warn escala a error.
  [ "$status" -eq 1 ]
}

# -----------------------------------------------------------------------------
# Alcance: TODAS las ramas, no solo la de por defecto
# -----------------------------------------------------------------------------
# La primera version de esta deteccion solo consultaba default_branch. Con ese
# alcance no habria encontrado la capa clasica de la rama dev de
# spark-match-07-article, la que hubo que retirar a mano el 2026-08-06.
#
# El barrido completo sobre la organizacion devolvio 9 ramas protegidas en 5
# repos y 4 de ellas estaban en dev, asi que el alcance corto se dejaba fuera
# casi la mitad de los hallazgos.

# Igual que write_legacy_protection pero para una rama concreta.
write_legacy_protection_for() {
  cat > "fixtures/legacy-protection-$1.json" <<'EOF'
{
  "enforce_admins": { "enabled": false },
  "required_pull_request_reviews": {
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  }
}
EOF
}

@test "legacy: detecta proteccion en una rama que NO es la de por defecto" {
  # spark-match-bar declara refs/heads/dev en el manifiesto. main queda limpia.
  write_legacy_protection_for dev

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-bar

  [[ "$output" == *"legacy-protection"* ]]
  [[ "$output" == *"dev"* ]]
}

@test "legacy: una rama no-default protegida es drift (exit 1), no verde" {
  write_legacy_protection_for dev

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-bar

  [ "$status" -eq 1 ]
}

@test "legacy: main y dev protegidas producen DOS hallazgos, no uno" {
  write_legacy_protection          # main (la de por defecto)
  write_legacy_protection_for dev

  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-bar

  count=$(json_output | jq '[.[] | select(.state == "legacy-protection")] | length')
  [ "$count" -eq 2 ]
}

@test "legacy: cada hallazgo dice si es la rama por defecto o no" {
  write_legacy_protection
  write_legacy_protection_for dev

  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-bar

  json_output | jq -e '.[] | select(.branch == "main") | .is_default == true' >/dev/null
  json_output | jq -e '.[] | select(.branch == "dev") | .is_default == false' >/dev/null
}

@test "legacy: una rama protegida sin capa clasica no es drift" {
  # release/1.x aparece en el listado de ramas protegidas, que incluye tambien
  # las protegidas solo por ruleset. El endpoint clasico da 404 ahi, asi que no
  # hay nada que reportar: el listado acota candidatos, no decide.
  echo "release/1.x" > fixtures/protected-branches

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  [[ "$output" != *"legacy-protection"* ]]
}

@test "legacy: una rama solo del listado protegido tambien se inspecciona" {
  echo "hotfix" > fixtures/protected-branches
  write_legacy_protection_for hotfix

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  [[ "$output" == *"legacy-protection"* ]]
  [[ "$output" == *"hotfix"* ]]
}

@test "legacy: la rama por defecto se mira aunque el listado venga vacio" {
  # Si el listado de ramas protegidas falla o no devuelve nada, la rama por
  # defecto tiene que seguir inspeccionandose. Es la red de seguridad.
  : > fixtures/protected-branches
  write_legacy_protection

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  [[ "$output" == *"legacy-protection"* ]]
}

@test "legacy: no se repite una rama que llega por dos vias" {
  # main llega por el listado protegido, por default_branch y por el manifiesto.
  # Tiene que salir UNA vez, no tres.
  echo "main" > fixtures/protected-branches
  write_legacy_protection

  run bash "$SCRIPT" --check --json --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo

  count=$(json_output | jq '[.[] | select(.state == "legacy-protection")] | length')
  [ "$count" -eq 1 ]
}

@test "legacy: --prune borra TODAS las ramas protegidas, no solo la primera" {
  write_legacy_protection
  write_legacy_protection_for dev

  run bash "$SCRIPT" --apply --prune-legacy-protection \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-bar

  grep -qE "DELETE repos/spark-match/spark-match-bar/branches/main/protection" "$BATS_TEST_TMPDIR/gh.log"
  grep -qE "DELETE repos/spark-match/spark-match-bar/branches/dev/protection" "$BATS_TEST_TMPDIR/gh.log"
}

@test "legacy: el DELETE fallido de una rama no oculta al resto" {
  write_legacy_protection
  write_legacy_protection_for dev
  touch fixtures/legacy-delete-rejected

  run bash "$SCRIPT" --apply --json --prune-legacy-protection \
    --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-bar

  fails=$(json_output | jq '[.[] | select(.reason == "legacy-protection-delete-failed")] | length')
  [ "$fails" -eq 2 ]
  [ "$status" -ne 0 ]
}

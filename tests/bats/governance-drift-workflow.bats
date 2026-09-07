#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# governance-drift-workflow.bats
# =============================================================================
# El workflow que vigila los rulesets solo puede LEER.
#
# POR QUE. `configure-repo-rulesets.sh --apply` hace PUT sobre los rulesets de
# los diez repositorios de la organizacion. Es la accion con mas alcance
# destructivo de todo el catalogo: un `--apply` con un manifiesto equivocado
# reescribe la proteccion de rama de la organizacion entera.
#
# Que ese script pase a correr solo, en cron, es util mientras se limite a
# mirar. Cambiar `--check` por `--apply` en este fichero convertiria una alarma
# en un reconciliador automatico sin humano delante, y el cambio son seis
# caracteres en una linea que nadie vuelve a leer.
#
# La otra mitad del guard es el `schedule`: sin el, el workflow existe pero no
# se ejecuta, que es exactamente la situacion que vino a resolver. El script
# llevaba desde siempre sin ejecutarse, y por eso el drift de
# `require_extra_approval_for_unattributed_changes` estuvo semanas sin que
# nadie lo viera.
# =============================================================================

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  WF="${REPO_ROOT}/.github/workflows/governance-drift.yml"
}

@test "governance-drift: el workflow existe" {
  [ -f "$WF" ]
}

@test "governance-drift: invoca el reconciliador con --check" {
  grep -qE 'configure-repo-rulesets\.sh[[:space:]]+--check' "$WF"
}

# Devuelve las lineas que EJECUTAN el reconciliador, descartando las que solo
# lo mencionan. El Job Summary imprime los comandos que un humano puede correr
# a mano, y ahi `--apply` aparece a proposito: un `echo` no ejecuta nada. Lo
# que este guard vigila es la invocacion real.
lineas_que_ejecutan() {
  grep -nE 'configure-repo-rulesets\.sh' "$WF"     | grep -vE '^[0-9]+:[[:space:]]*#'     | grep -vE '^[0-9]+:[[:space:]]*echo[[:space:]]'     || true
}

@test "governance-drift: NUNCA ejecuta --apply" {
  # El guard que de verdad importa. Ver la cabecera de este fichero.
  local ejecuciones
  ejecuciones="$(lineas_que_ejecutan)"
  [ -n "$ejecuciones" ]
  if echo "$ejecuciones" | grep -q -- '--apply'; then
    echo "# El workflow EJECUTA el reconciliador con --apply:" >&2
    echo "$ejecuciones" | grep -- '--apply' >&2
    return 1
  fi
}

@test "governance-drift: toda ejecucion lleva --check" {
  # El guard del guard: si el extractor dejara de reconocer la linea, el test
  # de arriba pasaria siempre por no tener nada que mirar.
  local ejecuciones
  ejecuciones="$(lineas_que_ejecutan)"
  [ -n "$ejecuciones" ]
  while IFS= read -r linea; do
    [[ -z "$linea" ]] && continue
    [[ "$linea" == *"--check"* ]]
  done <<<"$ejecuciones"
}

@test "governance-drift: no ejecuta ninguna de las banderas destructivas" {
  # --prune-unexpected y --prune-legacy-protection borran rulesets y proteccion
  # clasica. Ninguna tiene sentido en un workflow desatendido.
  run grep -nE '^[^#]*--prune-(unexpected|legacy-protection)' "$WF"
  [ "$status" -ne 0 ]
}

@test "governance-drift: corre en schedule (si no, no vigila nada)" {
  grep -qE '^[[:space:]]+- cron:' "$WF"
}

@test "governance-drift: se puede lanzar a mano con workflow_dispatch" {
  grep -qE '^[[:space:]]+workflow_dispatch:' "$WF"
}

@test "governance-drift: los permisos del token son de solo lectura" {
  # `permissions:` a nivel de workflow no debe conceder ningun write. El script
  # no escribe en este repositorio; lo que necesita es el token de la App.
  local bloque
  bloque="$(awk '/^permissions:/{p=1;next} p&&/^[a-z]/{p=0} p' "$WF")"
  [ -n "$bloque" ]
  ! echo "$bloque" | grep -qE ':[[:space:]]*write'
}

@test "governance-drift: el resultado llega al job summary" {
  # Sin esto, un fallo en rojo obliga a abrir los logs para saber si el drift
  # es cosmetico o es el permiso de merge.
  grep -q 'GITHUB_STEP_SUMMARY' "$WF"
}

@test "governance-drift: propaga el exit code del script" {
  # Tragarselo dejaria el workflow siempre en verde y la alarma muda.
  grep -qE 'exit[[:space:]]+"\$\{code\}"' "$WF"
}

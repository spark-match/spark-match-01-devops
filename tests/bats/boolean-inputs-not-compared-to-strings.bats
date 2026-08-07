#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# boolean-inputs-not-compared-to-strings.bats
# =============================================================================
# Un input declarado `type: boolean` NUNCA debe compararse contra la cadena
# 'true' o 'false' en una expresion de GitHub.
#
# POR QUE. En las expresiones de GitHub, cuando los dos operandos de una
# comparacion son de tipos distintos, ambos se castean a numero:
#
#     true    -> 1
#     'true'  -> NaN   (la cadena no es un numero valido)
#
# y cualquier comparacion con NaN da falso, salvo `!=`, que da verdadero. De
# ahi las dos formas del mismo error:
#
#     inputs.dry-run != 'true'   ->  1 != NaN  ->  SIEMPRE CIERTO
#     inputs.dry-run == 'true'   ->  1 == NaN  ->  SIEMPRE FALSO
#
# La primera abre: el paso corre aunque la casilla este marcada. La segunda
# cierra: el paso no corre nunca. Las dos son silenciosas.
#
# La forma correcta es usar el booleano directamente:
#
#     if: !inputs.dry-run        # en vez de  inputs.dry-run != 'true'
#     if: inputs.enable-cleanup  # en vez de  inputs.enable-cleanup == 'true'
#
# Ojo: esto NO aplica a `steps.*.outputs.*` ni a `env.*`, que si son cadenas
# de verdad y deben compararse con comillas. La regla es solo para los inputs
# declarados `type: boolean` en el propio `workflow_call`.
#
# History:
#   - fix/booleanos-comparados-contra-cadenas: se anadio este guard al
#     encontrar 7 ocurrencias en 3 reusables. La mas grave estaba en
#     reusable-terraform-destroy.yml: la guarda `inputs.dry-run != 'true'`
#     hacia que la casilla `dry_run` -- que ademas viene marcada por defecto
#     en el caller -- no frenara el destroy, mientras el Job Summary, que si
#     comparaba bien porque lo hacia en shell, imprimia "Mode: dry-run (plan
#     only)". Las otras seis eran: `drift-only` en apply (x3), `enable-cleanup`
#     en destroy, y `permissions-write` en python-ci, que llevaba desde
#     siempre sin subir la cobertura.
# =============================================================================

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"
}

# Extrae los nombres de los inputs declarados `type: boolean` de un workflow.
# Solo mira dentro del bloque `inputs:` de `workflow_call`, para no confundir
# las claves de `secrets:`, que viven al mismo nivel de indentacion.
boolean_inputs_of() {
  awk '
    # Entramos al bloque de inputs (4 espacios, bajo workflow_call).
    /^    inputs:[[:space:]]*$/ { in_inputs = 1; next }
    # Cualquier clave a indentacion <= 4 que no sea la nuestra lo cierra.
    in_inputs && /^ {0,4}[a-zA-Z_-]+:/ { in_inputs = 0 }
    !in_inputs { next }
    # Nombre de input: clave a 6 espacios exactos.
    /^      [a-zA-Z][a-zA-Z0-9_-]*:[[:space:]]*$/ {
      name = $1; sub(/:$/, "", name); next
    }
    # Su tipo, a 8 espacios.
    /^        type:[[:space:]]*boolean[[:space:]]*$/ { if (name != "") print name }
  ' "$1"
}

@test "boolean-inputs: ningun input booleano se compara contra una cadena" {
  local offenders=()

  while IFS= read -r wf; do
    local names
    names="$(boolean_inputs_of "$wf")"
    [[ -z "$names" ]] && continue

    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      # inputs.<name> ==|!= 'true'|'false'  (comillas simples o dobles)
      local found
      found="$(grep -nE "inputs\.${name}[[:space:]]*[!=]=[[:space:]]*['\"](true|false)['\"]" "$wf" || true)"
      [[ -z "$found" ]] && continue
      while IFS= read -r hit; do
        [[ -z "$hit" ]] && continue
        offenders+=("$(basename "$wf"):${hit%%:*}  [${name}]")
      done <<<"$found"
    done <<<"$names"
  done < <(find "$WORKFLOWS_DIR" -maxdepth 1 -name 'reusable-*.yml' -type f | sort)

  if [ ${#offenders[@]} -ne 0 ]; then
    printf 'Inputs booleanos comparados contra cadenas (siempre ciertos o siempre falsos):\n' >&2
    printf '  %s\n' "${offenders[@]}" >&2
    printf '\nUsa el booleano directamente: `!inputs.x` en vez de `inputs.x != '"'"'true'"'"'`,\n' >&2
    printf 'e `inputs.x` en vez de `inputs.x == '"'"'true'"'"'`. Ver la cabecera de este fichero.\n' >&2
    return 1
  fi
}

@test "boolean-inputs: el extractor reconoce los booleanos que ya existen" {
  # Guard del propio guard: si el parser dejara de reconocer los inputs, el
  # test de arriba pasaria siempre por no tener nada que mirar. Estos tres
  # son booleanos declarados hoy; si alguno se renombra o cambia de tipo,
  # este test avisa en vez de que el guard se quede ciego en silencio.
  local found
  found="$(boolean_inputs_of "${WORKFLOWS_DIR}/reusable-terraform-destroy.yml")"

  [[ "$found" == *"dry-run"* ]]
  [[ "$found" == *"auto-approve"* ]]
  [[ "$found" == *"enable-cleanup"* ]]
}

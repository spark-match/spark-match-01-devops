#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# readme-fidelity.bats - el README describe lo que hay, no lo que hubo
# =============================================================================
# El README de este repo es el catalogo: quien busca una receta la busca aqui.
# Cuando se queda atras el fallo es silencioso, porque un documento no tiene
# forma de fallar. Medido el 2026-08-07, decia:
#
#   - "492 bats tests"            -> habia 539
#   - "seven layers"              -> la tabla tenia 6 filas
#   - 7 flags del reconciliador   -> el script acepta 12
#   - "9 of 9 repos compliant"    -> el manifiesto declaraba 10
#
# Ninguno rompia nada. Todos hacian que alguien leyera el catalogo y se llevara
# una idea falsa de que hay disponible.
#
# Estos tests NO vigilan cifras. Vigilar una cifra obliga a editar el README en
# cada commit, que es exactamente el mecanismo que produjo la deriva. Vigilan
# correspondencias: que lo documentado exista y que lo que existe este
# documentado.
#
# Hermeticos: leen el arbol y nada mas. Sin red, sin gh, sin AWS.
# =============================================================================

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  README="${REPO_ROOT}/README.md"
  WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"
}

# -----------------------------------------------------------------------------
@test "readme: todo reusable del arbol esta documentado" {
  # Por que: un reusable sin entrada en el catalogo es un reusable que nadie va
  # a usar. Se escribio, se testeo, y es invisible.
  local faltan=()

  while IFS= read -r f; do
    local name
    name="$(basename "$f")"
    grep -qF "$name" "$README" || faltan+=("$name")
  done < <(find "${WORKFLOWS_DIR}" -maxdepth 1 -name 'reusable-*.yml' | sort)

  if [ ${#faltan[@]} -ne 0 ]; then
    printf 'Reusables que existen y el README no menciona:\n' >&2
    printf '  %s\n' "${faltan[@]}" >&2
    return 1
  fi
}

# -----------------------------------------------------------------------------
@test "readme: no documenta reusables que ya no existen" {
  # Por que: el reverso del anterior, y el mas danino de los dos. Un reusable
  # borrado que sigue en el catalogo manda a alguien a llamar un `uses:` que
  # falla en tiempo de ejecucion, no de lectura.
  local fantasmas=()

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    [[ -f "${WORKFLOWS_DIR}/${name}" ]] || fantasmas+=("$name")
  done < <(grep -ohE 'reusable-[a-z0-9-]+\.yml' "$README" | sort -u)

  if [ ${#fantasmas[@]} -ne 0 ]; then
    printf 'Reusables que el README documenta y no existen en el arbol:\n' >&2
    printf '  %s\n' "${fantasmas[@]}" >&2
    return 1
  fi
}

# -----------------------------------------------------------------------------
@test "readme: los flags que atribuye al reconciliador existen en el script" {
  # Por que: aqui la deriva fue al reves de lo habitual. El README no inventaba
  # flags, se quedaba corto: omitia --prune-legacy-protection, que es el que
  # BORRA la proteccion de rama clasica. Documentar de menos en la parte
  # destructiva es peor que documentar de mas.
  #
  # El test comprueba la direccion que si puede romper a alguien: que ningun
  # flag citado en el README sea inexistente. La cobertura completa se delega a
  # `--help`, que el README ahora nombra como fuente autoritativa.
  local script="${REPO_ROOT}/scripts/configure-repo-rulesets.sh"
  [ -f "$script" ]

  local reales inventados=()
  # Sin anclar a principio de linea: `--help` se declara como `-h|--help)`.
  reales="$(grep -oE '\-\-[a-z-]+\)' "$script" | tr -d ')' | sort -u)"

  # Solo los flags citados en lineas que hablan DE ESTE script. El README
  # documenta 27 recetas y muchas tienen sus propios flags -- `--frozen` de
  # `uv sync`, por ejemplo -- que no tienen nada que ver con el reconciliador.
  while IFS= read -r flag; do
    [[ -z "$flag" ]] && continue
    printf '%s\n' "$reales" | grep -qx -- "$flag" || inventados+=("$flag")
  done < <(grep 'configure-repo-rulesets' "$README" | grep -oE '`--[a-z-]+`' | tr -d '`' | sort -u)

  if [ ${#inventados[@]} -ne 0 ]; then
    printf 'Flags que el README cita y configure-repo-rulesets.sh no acepta:\n' >&2
    printf '  %s\n' "${inventados[@]}" >&2
    return 1
  fi
}

# -----------------------------------------------------------------------------
@test "readme: no congela un recuento de compliance" {
  # Por que: habia una seccion "Current compliance (snapshot 2026-07-26)" con
  # "9 of 9 repos compliant". Se quedo obsoleta dos veces: `.github` se declaro
  # el 2026-08-06 (pasaron a 10) y 02-infrastructure estuvo tres dias en drift
  # mientras esta pagina afirmaba cumplimiento total.
  #
  # Una cifra congelada en prosa no puede reportar deriva. Para eso esta
  # `--check`, que la calcula contra los rulesets vivos. Este test impide que
  # vuelva a aparecer un recuento de ese tipo.
  if grep -nE '[0-9]+ of [0-9]+ repos' "$README" >&2; then
    printf '\nEl README congela un recuento de compliance.\n' >&2
    printf 'Usa `configure-repo-rulesets.sh --check`, que lo calcula contra\n' >&2
    printf 'los rulesets vivos, en vez de una foto que envejece sola.\n' >&2
    return 1
  fi
}

#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reconciler-status-checks.bats - statusChecks del manifesto son los reales
# =============================================================================
# Asegura que cada check name en el manifest coincida 1-a-1 con el context
# que los workflows de ese repo reportan via la API de GitHub Actions. Sin
# esto, --apply pone nombres placeholder como `tflint (env=dev)` mientras los
# workflows reportan `tflint / tflint-`, y todas las PRs quedan pegadas en
# "Expected — Waiting for status to be reported" indefinidamente.
# =============================================================================

load 'helpers/reconciler'

setup() {
  load 'helpers/reconciler'
}

# -----------------------------------------------------------------------------
# Spark-match-01-devops: 3 checks oficiales
# -----------------------------------------------------------------------------

@test "spark-match-01-devops statusChecks use -ci suffix (the actionlint/gitleaks/yamllint CI suffix)" {
  jq -e '
    .repositories["spark-match-01-devops"].statusChecks
    | sort == [
        "actionlint / actionlint-ci",
        "gitleaks / gitleaks-ci",
        "lint-commits / commitlint",
        "yamllint / yamllint-ci"
      ]
  ' "$MANIFEST" >/dev/null
}

@test "spark-match-01-devops statusChecks MUST NOT contain legacy '(env=ci)' notation" {
  jq -e '
    .repositories["spark-match-01-devops"].statusChecks
    | all(. | contains("(env=") | not)
  ' "$MANIFEST" >/dev/null
}

@test "spark-match-01-devops requires the commitlint context a pull request actually reports" {
  # Antes esto exigia "lint-commits / commitlint-main". Ese context solo se
  # publica en un push a main: en un PR el job se llamaba commitlint-<rama>,
  # asi que el check requerido no llegaba nunca y el PR quedaba colgado en
  # "Expected - Waiting for status to be reported" -- el mismo fallo que
  # describe la cabecera de este fichero.
  jq -e '
    .repositories["spark-match-01-devops"].statusChecks
    | any(. == "lint-commits / commitlint")
  ' "$MANIFEST" >/dev/null
}

@test "reusable-commitlint job name MUST be static so it can gate a merge" {
  # Un required status check se identifica por su nombre. Si el nombre del job
  # lleva dentro una expresion (la rama, el actor, el SHA), el context cambia
  # en cada run y el ruleset espera uno que no llega. Este test falla si
  # alguien vuelve a meter ${{ ... }} en el name: del job.
  local wf="${REPO_ROOT}/.github/workflows/reusable-commitlint.yml"
  [ -f "$wf" ]

  # Solo el name: del job, no los comentarios que explican por que.
  run grep -E '^ {4}name:.*\$\{\{' "$wf"
  [ "$status" -ne 0 ]
}

# -----------------------------------------------------------------------------
# Spark-match-02-infrastructure: 8 checks alineados con workflows reales
# -----------------------------------------------------------------------------

@test "spark-match-02-infrastructure statusChecks contain exactly 8 real entries" {
  jq -e '
    (.repositories["spark-match-02-infrastructure"].statusChecks | length == 8)
  ' "$MANIFEST" >/dev/null
}

@test "spark-match-02-infrastructure statusChecks use real check contexts reported by workflows" {
  jq -e '
    .repositories["spark-match-02-infrastructure"].statusChecks
    | sort == [
        "Checkov",
        "gitleaks / gitleaks-",
        "lint-commits / commitlint",
        "plan-dev / plan-",
        "quality / bats",
        "sonar-terraform / sonar-terraform-dev",
        "terraform-validate / terraform-validate-",
        "tflint / tflint-"
      ]
  ' "$MANIFEST" >/dev/null
}

@test "spark-match-02-infrastructure statusChecks MUST NOT contain placeholder names like 'Plan (dev) / Plan (dev)'" {
  jq -e '
    .repositories["spark-match-02-infrastructure"].statusChecks
    | all(. | test("^Plan \\(dev\\) / Plan \\(dev\\)$") | not)
  ' "$MANIFEST" >/dev/null
}

@test "spark-match-02-infrastructure statusChecks MUST NOT contain '(env=dev)' placeholder" {
  jq -e '
    .repositories["spark-match-02-infrastructure"].statusChecks
    | all(. | contains("(env=") | not)
  ' "$MANIFEST" >/dev/null
}

# -----------------------------------------------------------------------------
# Cross-repo invariant
# -----------------------------------------------------------------------------

@test "every statusChecks entry is a non-empty string" {
  jq -e '
    .repositories
    | to_entries
    | map(.value.statusChecks // [])
    | flatten
    | all(type == "string" and length > 0)
  ' "$MANIFEST" >/dev/null
}

@test "no duplicate statusChecks within a repo" {
  jq -e '
    .repositories
    | to_entries
    | map(select((.value.statusChecks // []) | length > 0))
    | map(.key as $repo | {repo: $repo, dups: (.value.statusChecks | group_by(.) | map(select(length > 1) | .[0]))})
    | all(.dups | length == 0)
  ' "$MANIFEST" >/dev/null
}

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
# Spark-match-02-infrastructure: los 26 contextos que sus workflows publican
# -----------------------------------------------------------------------------

@test "spark-match-02-infrastructure statusChecks use real check contexts reported by workflows" {
  # Esta lista duplica el manifiesto a proposito. No es un descuido: es un
  # cable trampa. Los contextos de ese repo no se pueden derivar aqui -- sus
  # workflows viven en otro repositorio -- asi que lo unico que este fichero
  # puede garantizar es que la lista no cambie sin que alguien lo haga a
  # sabiendas, en dos sitios.
  #
  # Y el cable sirve: el 2026-08-07 el manifiesto declaraba 8 contextos contra
  # los 21 que el ruleset exigia de verdad. Como el manifiesto es lo que el
  # reconciliador ESCRIBE, un `--apply` habria cambiado 21 puertas por 8,
  # tirando los 14 `checkov-*` de la matriz. Los cuatro modulos mas nuevos --
  # agent-service, ecr, frontend-hosting, oidc-frontend -- no estaban
  # requeridos en ninguno de los dos lados.
  #
  # El test del recuento exacto que habia aqui se elimino: `sort ==` ya fija
  # el numero, asi que solo anadia un segundo sitio donde equivocarse.
  jq -e '
    .repositories["spark-match-02-infrastructure"].statusChecks
    | sort == [
        "checkov-live/dev",
        "checkov-live/prod",
        "checkov-modules/agent-service",
        "checkov-modules/dynamodb-idempotency",
        "checkov-modules/ecr",
        "checkov-modules/endpoints",
        "checkov-modules/eventbridge-bus",
        "checkov-modules/frontend-hosting",
        "checkov-modules/kms",
        "checkov-modules/networking",
        "checkov-modules/notifications",
        "checkov-modules/oidc-frontend",
        "checkov-modules/oidc-github",
        "checkov-modules/rds-postgres",
        "checkov-modules/secrets-bootstrap",
        "checkov-modules/security-groups",
        "checkov-modules/ssm-bootstrap",
        "checkov-modules/storage-sam-artifacts",
        "gitleaks / gitleaks-",
        "lint-commits / commitlint",
        "lint-pr-title",
        "plan-dev / plan-",
        "quality / bats",
        "sonar-terraform / sonar-terraform-dev",
        "terraform-validate / terraform-validate-",
        "tflint / tflint-"
      ]
  ' "$MANIFEST" >/dev/null
}

@test "spark-match-02-infrastructure MUST NOT require the aggregate 'Checkov' context" {
  # Este si es un invariante y no una foto: codifica una decision, asi que no
  # caduca cuando se anada un modulo.
  #
  # `Checkov` es el context que Code Scanning deriva del SARIF, distinto de los
  # `checkov-*` de la matriz. Se quito de requeridos el 2026-08-04: se queda en
  # NEUTRAL cuando un pull request de sync trae re-reportes de alertas
  # preexistentes, y un context NEUTRAL no satisface nunca la regla, asi que
  # bloquea el PR para siempre y solo se sale con bypass de admin.
  #
  # Estuvo en el manifiesto hasta el 2026-08-07 pese a llevar tres dias fuera
  # del ruleset vivo, o sea que un `--apply` lo habria repuesto sin que nadie
  # se enterara hasta el siguiente sync.
  jq -e '
    .repositories["spark-match-02-infrastructure"].statusChecks
    | all(. != "Checkov")
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

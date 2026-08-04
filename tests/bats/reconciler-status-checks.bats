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

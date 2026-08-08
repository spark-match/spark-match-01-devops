#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# sonar-quality-gate-honesty.bats - the enforce-quality-gate step must not lie
# =============================================================================
# The three sonar recipes (typescript, python, terraform) carry the same
# `enforce-quality-gate` block verbatim. Until 2026-08-07 it read:
#
#     if [ -z "${STEPS_QG_OUTPUTS_QUALITY_GATE_STATUS}" ]; then
#       echo "::error::... polling timed out (>300s) ... Re-run when service is healthy."
#
# That treats an empty status as proof of a timeout. It is empty after ANY
# upstream failure, so every scan that died before publishing was reported as a
# SonarCloud outage, with a remedy -- wait and re-run -- that could not work.
#
# Measured on spark-match-03-backend PR #200: the scanner exited in 13.6
# seconds with `Could not find the pullrequest with key '200'`, because the
# project was bound to the wrong GitHub repository, and the job reported a
# 300-second timeout and suggested maintenance. Nothing timed out.
#
# This is worse than failing open. It fails with a false diagnosis, which sends
# whoever reads it in the wrong direction.
#
# `.scannerwork/report-task.txt` is what separates the two cases: the scanner
# writes it on success, so its absence means the scan failed and the gate was
# never evaluated.
#
# This file guards the invariant across ALL THREE recipes, because only
# reusable-sonar-python.bats existed and a shared block guarded in one of three
# places is the same half-coverage this catalog keeps finding.
# =============================================================================

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  WORKFLOWS=(
    "$REPO_ROOT/.github/workflows/reusable-sonar-typescript.yml"
    "$REPO_ROOT/.github/workflows/reusable-sonar-python.yml"
    "$REPO_ROOT/.github/workflows/reusable-sonar-terraform.yml"
  )
}

# Extract the enforce-quality-gate step: from its `- name:` line up to the next
# one. Deliberately not `grep -A<n>`: a fixed window measures distance from the
# step name rather than the step's content, and adding a comment silently
# breaks it. That is exactly how the previous version of this assertion failed.
enforce_step() {
  awk '/^[[:space:]]+- name: enforce-quality-gate/{f=1;next} f&&/^[[:space:]]+- name: /{exit} f' "$1"
}

@test "sonar recipes: all three declare an enforce-quality-gate step" {
  for wf in "${WORKFLOWS[@]}"; do
    [ -f "$wf" ] || { echo "# missing workflow: $wf" >&2; return 1; }
    local step
    step="$(enforce_step "$wf")"
    [ -n "$step" ] || { echo "# no enforce-quality-gate step in $wf" >&2; return 1; }
  done
}

@test "sonar recipes: a failed scan is not reported as a polling timeout" {
  for wf in "${WORKFLOWS[@]}"; do
    local step
    step="$(enforce_step "$wf")"
    if [[ "$step" != *"report-task.txt"* ]]; then
      echo "# $(basename "$wf"): enforce-quality-gate does not check for" >&2
      echo "# .scannerwork/report-task.txt, so it cannot tell a failed scan" >&2
      echo "# from a real polling timeout and will report the wrong cause." >&2
      return 1
    fi
  done
}

@test "sonar recipes: the timeout message survives, for the case that is real" {
  # The fix must not solve a false diagnosis by deleting the true one. A
  # genuine >300s poll is still possible and still deserves its own message.
  for wf in "${WORKFLOWS[@]}"; do
    local step
    step="$(enforce_step "$wf")"
    [[ "$step" == *"polling timed out"* ]] || {
      echo "# $(basename "$wf"): lost the genuine-timeout branch" >&2
      return 1
    }
  done
}

@test "sonar recipes: a FAILED gate is still reported as a failed gate" {
  for wf in "${WORKFLOWS[@]}"; do
    local step
    step="$(enforce_step "$wf")"
    [[ "$step" == *"Quality Gate FAILED"* ]] || {
      echo "# $(basename "$wf"): lost the FAILED branch" >&2
      return 1
    }
    [[ "$step" == *"exit 1"* ]] || {
      echo "# $(basename "$wf"): no longer exits non-zero" >&2
      return 1
    }
  done
}

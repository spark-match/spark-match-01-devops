#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# cleanup-batch-pr8.bats - regression tests for PR-8 cleanup batch
# =============================================================================
# Locks down:
#   - defaults.run.shell: bash on every workflow that has a defaults: block
#   - reusable-terraform-destroy.yml has pull-requests: write permission
#   - reusable-terraform-* workflows accept environment-name as alias of environment
#   - reconciler.bash no longer tries to load bats-support / bats-assert
#   - NO workflow has 'shell: bash' inside a workflow_call.inputs block
#     (regression guard against the PR-174 mistake)
# =============================================================================

WORKFLOWS_DIR="$BATS_TEST_DIRNAME/../../.github/workflows"

@test "every workflow with a defaults: block also sets defaults.run.shell: bash" {
  local missing=()
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if grep -q "^    defaults:" "$f"; then
      if ! grep -A4 "^    defaults:" "$f" | grep -q "shell: bash"; then
        missing+=("$f")
      fi
    fi
  done < <(find "$WORKFLOWS_DIR" -maxdepth 1 -name '*.yml' -type f)
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "# workflows with defaults: block missing shell: bash:"
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "no workflow has 'shell: bash' inside a workflow_call.inputs block" {
  # Regression guard: a previous PR (#174) accidentally inserted 'shell: bash'
  # under inputs.working-directory declarations (which is not valid YAML
  # schema for that section). Any future script that bulk-adds 'shell: bash'
  # to lines containing 'working-directory:' MUST distinguish step context
  # from inputs context. This test catches that mistake.
  local offenders=()
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    # Walk the YAML tracking a 3-deep state stack:
    #   on > workflow_call > inputs / outputs / secrets.
    # Anything else (top-level keys, jobs, steps) resets the stack.
    # If we see `shell: bash` while in_inputs, that's the bug we want to catch.
    # awk returns 0 if clean, 1 if found (so !awk is true when clean).
    if ! awk '
      BEGIN { in_on=0; in_wc=0; in_inputs=0; in_outputs=0; found=0 }
      {
        # Top-level key (no leading whitespace, key:, optional trailing ws).
        if ($0 ~ /^[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]*$/) {
          in_on=0; in_wc=0; in_inputs=0; in_outputs=0
          if ($0 ~ /^on:[[:space:]]*$/) in_on=1
          next
        }
        if ($0 ~ /^[[:space:]]*#/) { next }
        if (in_on && $0 ~ /^[[:space:]]+workflow_call:[[:space:]]*$/) {
          in_wc=1; in_inputs=0; in_outputs=0
          next
        }
        if (in_wc && $0 ~ /^[[:space:]]+inputs:[[:space:]]*$/) {
          in_inputs=1; in_outputs=0
          next
        }
        if (in_wc && $0 ~ /^[[:space:]]+outputs:[[:space:]]*$/) {
          in_outputs=1; in_inputs=0
          next
        }
        if (in_wc && $0 ~ /^[[:space:]]+secrets:[[:space:]]*$/) {
          in_inputs=0; in_outputs=0
          next
        }
        if (in_inputs && $0 ~ /shell:[[:space:]]+bash/) {
          print FILENAME ":" NR ": " $0
          found=1
        }
      }
      END { exit (found ? 1 : 0) }
    ' "$f"; then
      offenders+=("$f")
    fi
  done < <(find "$WORKFLOWS_DIR" -maxdepth 1 -name '*.yml' -type f)
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "# workflows with 'shell: bash' inside inputs block:"
    printf '  %s\n' "${offenders[@]}"
    return 1
  fi
}

@test "reusable-terraform-destroy.yml declares pull-requests: write permission" {
  # marocchino/sticky-pull-request-comment@v3 (used twice in the workflow)
  # requires pull-requests: write at the job or workflow level.
  local block
  block=$(awk '
    /^permissions:/ { in_block=1; next }
    in_block && /^[a-z]/ { in_block=0 }
    in_block { print }
  ' "$WORKFLOWS_DIR/reusable-terraform-destroy.yml")
  echo "# permissions block: $block"
  echo "$block" | grep -q "pull-requests:[[:space:]]*write"
}

@test "reusable-terraform-destroy.yml uses sticky-pull-request-comment at least once" {
  grep -q "marocchino/sticky-pull-request-comment" "$WORKFLOWS_DIR/reusable-terraform-destroy.yml"
}

@test "reusable-terraform-apply.yml declares environment-name input" {
  grep -qE '^[[:space:]]+environment-name:' "$WORKFLOWS_DIR/reusable-terraform-apply.yml"
}

@test "reusable-terraform-destroy.yml declares environment-name input" {
  grep -qE '^[[:space:]]+environment-name:' "$WORKFLOWS_DIR/reusable-terraform-destroy.yml"
}

@test "reusable-terraform-plan.yml declares environment-name input" {
  grep -qE '^[[:space:]]+environment-name:' "$WORKFLOWS_DIR/reusable-terraform-plan.yml"
}

@test "reusable-terraform-apply.yml environment input description mentions 'Deprecated alias'" {
  local desc
  desc=$(awk '
    /^      environment:/ { in_block=1; next }
    in_block && /^      [a-z]/ { exit }
    in_block { print }
  ' "$WORKFLOWS_DIR/reusable-terraform-apply.yml")
  echo "# desc: $desc"
  [[ "$desc" == *"Deprecated alias"* ]]
}

@test "reusable-terraform-destroy.yml environment input description mentions 'Deprecated alias'" {
  local desc
  desc=$(awk '
    /^      environment:/ { in_block=1; next }
    in_block && /^      [a-z]/ { exit }
    in_block { print }
  ' "$WORKFLOWS_DIR/reusable-terraform-destroy.yml")
  [[ "$desc" == *"Deprecated alias"* ]]
}

@test "reusable-terraform-plan.yml environment input description mentions 'Deprecated alias'" {
  local desc
  desc=$(awk '
    /^      environment:/ { in_block=1; next }
    in_block && /^      [a-z]/ { exit }
    in_block { print }
  ' "$WORKFLOWS_DIR/reusable-terraform-plan.yml")
  [[ "$desc" == *"Deprecated alias"* ]]
}

@test "reusable-terraform-* workflows prefer environment-name over environment" {
  for wf in reusable-terraform-apply.yml reusable-terraform-destroy.yml reusable-terraform-plan.yml; do
    grep -q 'inputs.environment-name || inputs.environment || inputs.working-directory' "$WORKFLOWS_DIR/$wf" \
      || { echo "# $wf missing the precedence chain"; return 1; }
  done
}

@test "reconciler.bash no longer references bats-support or bats-assert" {
  local helper="$BATS_TEST_DIRNAME/../helpers/reconciler.bash"
  ! grep -E 'bats-support|bats-assert|load_bats_helpers' "$helper"
}
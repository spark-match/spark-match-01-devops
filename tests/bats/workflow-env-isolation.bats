#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# workflow-env-isolation.bats - repo-wide regression guards against the
# code-injection anti-pattern that PR-G2 and this cleanup PR
# (quality.yml + release-please.yml) closed.
#
# Rule: NO `run:` block in any workflow may interpolate ${{ inputs.* }},
# ${{ steps.*.outputs.* }}, or ${{ secrets.* }} directly. Every such
# interpolation must be env-isolated: declare the value under `env:` as
# SCREAMING_SNAKE_CASE, then reference it as ${VAR} in the shell.
#
# Why: GitHub Actions evaluates ${{ }} BEFORE bash sees the shell script.
# If the substituted value contains $(...), backticks, or shell
# metacharacters, bash evaluates them as code. CodeQL flags caller-input
# versions as 'Code injection' (see alerts 508-517, closed by PR #183).
# Same risk applies to step outputs (lower-severity because the step
# output is repo-controlled, not caller-controlled, but the pattern is
# identical and the fix is identical).
#
# IMPORTANT: this test tracks THREE block states correctly:
#   - in_env: inside `env:` block (lines are INPUT DECLARATIONS, OK)
#   - in_run: inside `run: |` block (lines are SHELL CODE, must be env-isolated)
#   - in_with / if / etc: skip
# A previous version of this test confused env: lines with run: lines,
# producing massive false positives. See PR-cleanup commit message.
# =============================================================================

WORKFLOWS_DIR="$BATS_TEST_DIRNAME/../../.github/workflows"

# State machine: track YAML step blocks.
# Returns offender lines (one per line) via the offenders array variable.
# Usage: scan_workflow "$workflow_file" "inputs|steps|secrets"
scan_workflow() {
  local wf="$1"
  local pattern="$2"
  local -a offenders=()
  # step_indent = indent of the `- name:` line (e.g. 6 for jobs.X.steps).
  # env_indent = indent of the `env:` block inside the step.
  # run_indent = indent of the `run: |` block inside the step.
  # If we're inside env: AND in_env_indent > line indent, we skip.
  local in_env=0
  local env_indent=-1
  local in_run=0
  local run_indent=-1
  local line_num=0
  local match
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    # Skip blank lines and comments.
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [[ "$line" =~ ^[[:space:]]*# ]]; then continue; fi

    if [[ $in_env -eq 1 ]]; then
      # Inside env: block. Exit if a sibling key at <= env_indent appears
      # (and it's NOT `with:` or similar — we exit on ANY non-list item).
      if [[ "$line" =~ ^([[:space:]]+)[A-Za-z_-]+:[[:space:]]*[^:[:space:]] ]]; then
        local ind="${#BASH_REMATCH[1]}"
        if [[ $ind -le $env_indent ]]; then
          in_env=0
          env_indent=-1
        fi
      elif [[ "$line" =~ ^([[:space:]]+)-[[:space:]] ]]; then
        # list item at <= env_indent means env block ended
        local ind="${#BASH_REMATCH[1]}"
        if [[ $ind -le $env_indent ]]; then
          in_env=0
          env_indent=-1
        fi
      fi
      # If still inside env: block, skip (these are declaration lines).
      if [[ $in_env -eq 1 ]]; then
        continue
      fi
    fi

    if [[ $in_run -eq 1 ]]; then
      # Inside run: block. The block continues until a sibling key at
      # <= run_indent.
      # A line inside run: either starts with whitespace+text (shell
      # code) or is blank.
      # A sibling key (e.g. `with:`, `if:`, `name:`, `env:`, `- name:`)
      # at indent <= run_indent ENDS the block.
      local is_sibling=0
      if [[ "$line" =~ ^([[:space:]]+)-[[:space:]]name: ]]; then
        is_sibling=1
      elif [[ "$line" =~ ^([[:space:]]+)[a-zA-Z_-]+:[[:space:]]*[^|[:space:]] ]]; then
        # `key: value` (not pipe) at indent <= run_indent ends the block.
        local ind="${#BASH_REMATCH[1]}"
        if [[ $ind -le $run_indent ]]; then
          is_sibling=1
        fi
      elif [[ "$line" =~ ^([[:space:]]+)[a-zA-Z_-]+:[[:space:]]*$ ]]; then
        local ind="${#BASH_REMATCH[1]}"
        if [[ $ind -le $run_indent ]]; then
          is_sibling=1
        fi
      fi
      if [[ $is_sibling -eq 1 ]]; then
        in_run=0
        run_indent=-1
      else
        # Still inside run: block. Check for interpolation.
        case "$pattern" in
          inputs)
            match='\$\{\{[[:space:]]*inputs\.'
            ;;
          steps)
            match='\$\{\{[[:space:]]*steps\.[a-zA-Z0-9_-]+\.outputs\.'
            ;;
          secrets)
            match='\$\{\{[[:space:]]*secrets\.'
            ;;
          *)
            match='\$\{\{[[:space:]]*(inputs|steps|secrets)\.'
            ;;
        esac
        if [[ "$line" =~ $match ]]; then
          offenders+=("$wf:$line_num: $line")
        fi
        continue
      fi
    fi

    # We're not in env: or run:. Look for entry into either.
    if [[ "$line" =~ ^([[:space:]]+)env:[[:space:]]*$ ]]; then
      in_env=1
      env_indent="${#BASH_REMATCH[1]}"
      continue
    fi
    if [[ "$line" =~ ^([[:space:]]+)run:[[:space:]]*\|[[:space:]]*$ ]]; then
      in_run=1
      run_indent="${#BASH_REMATCH[1]}"
      continue
    fi
  done < "$wf"
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "  $wf has ${#offenders[@]} offender(s):"
    printf '    %s\n' "${offenders[@]}"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "no workflow has \${{ inputs.* }} interpolation inside any run: block" {
  local failed=()
  for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    [[ -f "$wf" ]] || continue
    if ! scan_workflow "$wf" "inputs"; then
      failed+=("$wf")
    fi
  done
  [[ ${#failed[@]} -eq 0 ]]
}

@test "no workflow has \${{ steps.*.outputs.* }} interpolation inside any run: block" {
  local failed=()
  for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    [[ -f "$wf" ]] || continue
    if ! scan_workflow "$wf" "steps"; then
      failed+=("$wf")
    fi
  done
  [[ ${#failed[@]} -eq 0 ]]
}

@test "no workflow has \${{ secrets.* }} interpolation inside any run: block" {
  local failed=()
  for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    [[ -f "$wf" ]] || continue
    if ! scan_workflow "$wf" "secrets"; then
      failed+=("$wf")
    fi
  done
  [[ ${#failed[@]} -eq 0 ]]
}

# Specific regression guards for the cleanup PR
# ---------------------------------------------------------------------------

@test "quality.yml: Run bats tests step run: block uses \${DISCOVER_FILES} shell var" {
  local wf="$WORKFLOWS_DIR/quality.yml"
  # Extract just the run: block body (after `run: |`, before next sibling key).
  # Use the scan_workflow-style state machine inline.
  local body
  body=$(awk '
    /- name: Run bats tests/{ step_indent=length($0); step_indent-=index($0,"- name: Run bats tests")+1; in_step=1; next }
    in_step==1 {
      # Exit at next - name: at same indent as the step (sibling step).
      if (match($0, /^[[:space:]]+- name: /) > 0) {
        sibl_ind=RLENGTH-9 # length("name: ") minus leading space
        if (sibl_ind <= step_indent) { in_step=0; exit }
      }
      # Extract only lines between `run: |` and the next sibling.
      if (match($0, /^[[:space:]]+run:[[:space:]]*\|/) > 0) {
        in_run=1; run_indent=RLENGTH; next
      }
      if (in_run==1) {
        # Exit on sibling key at <= run_indent.
        if (match($0, /^[[:space:]]+[a-zA-Z_-]+:[[:space:]]*[^|]/) > 0) {
          ind=RLENGTH; if (ind <= run_indent) { in_run=0; next }
        }
        print
      }
    }
  ' "$wf")
  echo "Run bats run: body:"
  echo "$body"
  echo "$body" | grep -qF '${DISCOVER_FILES}'
}

@test "quality.yml: Run pytest step run: block uses \${DISCOVER_FILES} shell var" {
  local wf="$WORKFLOWS_DIR/quality.yml"
  local body
  body=$(awk '
    /- name: Run pytest/{ step_indent=length($0); step_indent-=index($0,"- name: Run pytest")+1; in_step=1; next }
    in_step==1 {
      if (match($0, /^[[:space:]]+- name: /) > 0) {
        sibl_ind=RLENGTH-9
        if (sibl_ind <= step_indent) { in_step=0; exit }
      }
      if (match($0, /^[[:space:]]+run:[[:space:]]*\|/) > 0) {
        in_run=1; run_indent=RLENGTH; next
      }
      if (in_run==1) {
        if (match($0, /^[[:space:]]+[a-zA-Z_-]+:[[:space:]]*[^|]/) > 0) {
          ind=RLENGTH; if (ind <= run_indent) { in_run=0; next }
        }
        print
      }
    }
  ' "$wf")
  echo "Run pytest run: body:"
  echo "$body"
  echo "$body" | grep -qF '${DISCOVER_FILES}'
}

@test "release-please.yml: Log result step run: block uses env-isolated vars" {
  local wf="$WORKFLOWS_DIR/release-please.yml"
  local body
  body=$(awk '
    /- name: Log result/{ step_indent=length($0); step_indent-=index($0,"- name: Log result")+1; in_step=1; next }
    in_step==1 {
      if (match($0, /^[[:space:]]+- name: /) > 0) {
        sibl_ind=RLENGTH-9
        if (sibl_ind <= step_indent) { in_step=0; exit }
      }
      if (match($0, /^[[:space:]]+run:[[:space:]]*\|/) > 0) {
        in_run=1; run_indent=RLENGTH; next
      }
      if (in_run==1) {
        if (match($0, /^[[:space:]]+[a-zA-Z_-]+:[[:space:]]*[^|]/) > 0) {
          ind=RLENGTH; if (ind <= run_indent) { in_run=0; next }
        }
        print
      }
    }
  ' "$wf")
  echo "Log result run: body:"
  echo "$body"
  echo "$body" | grep -qF '${RELEASES_CREATED}'
  echo "$body" | grep -qF '${PULL_REQUEST_URL}'
  echo "$body" | grep -qF '${UPLOAD_URL}'
}
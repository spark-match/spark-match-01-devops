#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# bats tests for .github/actions/validate-workflow-inputs/validate.sh
#
# The script validates three kinds of constraints:
#   - REQUIRED  : pipe-separated list of required input names
#   - ENUMS     : JSON object mapping name -> array of allowed values
#   - PATTERNS  : JSON object mapping name -> regex pattern
#
# It reads from env vars (VALUES, REQUIRED, ENUMS, PATTERNS) and exits 0
# on success, 1 on validation error (with ::error:: annotations).

load 'helpers/common'

setup() {
  # Per-test env isolation: defaults to the script's "no constraints" state
  # so unset values in individual tests don't trigger `set -u` failures
  # when the script reads them. Tests that need specific values override
  # them.
  export VALUES='{}'
  export REQUIRED=''
  export ENUMS='{}'
  export PATTERNS='{}'
  TARGET="$ACTION_DIR/validate-workflow-inputs/validate.sh"
}

# Helper: run the action with the given env, capture stdout+stderr+exit.
run_validate() {
  run bash "$TARGET"
}

# ---------------------------------------------------------------------------
# REQUIRED
# ---------------------------------------------------------------------------

@test "validate: all required inputs present -> exits 0" {
  export VALUES='{"project-key":"abc","env":"dev"}'
  export REQUIRED='project-key|env'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All inputs validated"* ]]
}

@test "validate: missing required input -> exits 1 with ::error::" {
  export VALUES='{"project-key":"abc"}'
  export REQUIRED='project-key|env'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"::error::Input validation failed:"* ]]
  [[ "$output" == *"::error::  - env: required"* ]]
}

@test "validate: required input with null value -> exits 1" {
  export VALUES='{"project-key":null,"env":"dev"}'
  export REQUIRED='project-key|env'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"project-key: required"* ]]
}

@test "validate: required input with empty string -> exits 1" {
  export VALUES='{"project-key":"","env":"dev"}'
  export REQUIRED='project-key|env'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"project-key: required"* ]]
}

@test "validate: REQUIRED empty -> all checks skipped" {
  # The script reads $REQUIRED; under `set -u` it must be set, even to
  # empty. An empty REQUIRED means "no required keys", which skips the
  # required-loop entirely.
  export VALUES='{"project-key":""}'
  export REQUIRED=''
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# ENUMS
# ---------------------------------------------------------------------------

@test "validate: enum match -> exits 0" {
  export VALUES='{"sync-mode":"full"}'
  export ENUMS='{"sync-mode":["full","runtime-only"]}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

@test "validate: enum mismatch -> exits 1 with allowed list" {
  export VALUES='{"sync-mode":"banana"}'
  export ENUMS='{"sync-mode":["full","runtime-only"]}'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"::error::  - sync-mode: must be one of [full, runtime-only], got 'banana'"* ]]
}

@test "validate: enum value not provided (empty) -> skipped (no error)" {
  # An empty input should NOT trigger enum validation; only REQUIRED does.
  export VALUES='{"sync-mode":""}'
  export ENUMS='{"sync-mode":["full","runtime-only"]}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

@test "validate: multiple enums, only one invalid -> single error" {
  export VALUES='{"a":"x","b":"y"}'
  export ENUMS='{"a":["x","y"],"b":["only-b"]}'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  # Only b is invalid; a matches [x,y]. The error list should mention b
  # only (a is valid).
  [[ "$output" == *"b: must be one of [only-b]"* ]]
  [[ "$output" != *"a: must be one of"* ]]
}

@test "validate: ENUMS is {} placeholder -> skipped" {
  export VALUES='{"sync-mode":"anything"}'
  export ENUMS='{}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# PATTERNS
# ---------------------------------------------------------------------------

@test "validate: pattern match -> exits 0" {
  export VALUES='{"python-version":"3.12"}'
  export PATTERNS='{"python-version":"^[0-9]+\\.[0-9]+$"}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

@test "validate: pattern mismatch -> exits 1 with regex" {
  export VALUES='{"python-version":"three-twelve"}'
  export PATTERNS='{"python-version":"^[0-9]+\\.[0-9]+$"}'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"::error::  - python-version: must match /^[0-9]+\\.[0-9]+\$/, got 'three-twelve'"* ]]
}

@test "validate: pattern with empty value -> skipped (no error)" {
  export VALUES='{"python-version":""}'
  export PATTERNS='{"python-version":"^[0-9]+\\.[0-9]+$"}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

@test "validate: PATTERNS is {} placeholder -> skipped" {
  export VALUES='{"x":"anything"}'
  export PATTERNS='{}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Combined
# ---------------------------------------------------------------------------

@test "validate: all three constraint types together, all pass" {
  export VALUES='{"project-key":"abc","env":"dev","python-version":"3.12"}'
  export REQUIRED='project-key|env'
  export ENUMS='{"env":["dev","prod","staging"]}'
  export PATTERNS='{"python-version":"^[0-9]+\\.[0-9]+$"}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All inputs validated"* ]]
}

@test "validate: all three together, multiple errors collected (not first-fail)" {
  export VALUES='{"project-key":"","env":"banana","python-version":"abc"}'
  export REQUIRED='project-key|env'
  export ENUMS='{"env":["dev","prod"]}'
  export PATTERNS='{"python-version":"^[0-9]+\\.[0-9]+$"}'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  # All three error categories must appear.
  [[ "$output" == *"project-key: required"* ]]
  [[ "$output" == *"env: must be one of"* ]]
  [[ "$output" == *"python-version: must match"* ]]
}

@test "validate: VALUES malformed JSON -> script fails fast (set -e)" {
  # When VALUES is not valid JSON, jq exits non-zero on the first read.
  # Combined with `set -euo pipefail`, this terminates the script
  # without emitting the friendly error annotations. This pins the
  # current behaviour: malformed VALUES is a hard fail, not a graceful
  # error.
  export VALUES='not-json'
  export REQUIRED='project-key'
  run bash "$TARGET"
  [ "$status" -ne 0 ]
}

@test "validate: exit code on error is 1 (not 2, not undefined)" {
  export VALUES='{}'
  export REQUIRED='missing-key'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
}

@test "validate: all env vars set but empty -> exits 0" {
  # The CI reality: every input is passed as an env var (possibly empty).
  # Empty placeholders mean "no constraints defined" -> success.
  export VALUES='{}'
  export REQUIRED=''
  export ENUMS='{}'
  export PATTERNS='{}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All inputs validated"* ]]
}

# ---------------------------------------------------------------------------
# Boolean false / number 0 — regression guard for jq `//` semantics
# ---------------------------------------------------------------------------
# jq's `//` is the "alternative" operator and fires on BOTH null and
# false. Before PR-3, `.[$k] // ""` would treat a boolean false (a value
# that callers might intentionally pass to opt out of a feature) as
# "missing", so a required input with value false was wrongly reported
# as required. These tests pin the fix: only JSON null / missing key
# is treated as empty.

@test "validate: required input with boolean false -> exits 0 (not reported as missing)" {
  export VALUES='{"permissions-write":false,"project-key":"abc"}'
  export REQUIRED='permissions-write|project-key'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All inputs validated"* ]]
}

@test "validate: required input with number 0 -> exits 0" {
  export VALUES='{"coverage-threshold":0,"project-key":"abc"}'
  export REQUIRED='coverage-threshold|project-key'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

@test "validate: enum with boolean false value matching allowed list -> exits 0" {
  # Workflow inputs are strings; resolve_value() round-trips JSON false
  # to the string "false", so the enum list must also contain "false"
  # as a string. This is the realistic caller shape.
  export VALUES='{"fail-fast":false}'
  export ENUMS='{"fail-fast":["true","false"]}'
  run bash "$TARGET"
  [ "$status" -eq 0 ]
}

@test "validate: enum with boolean false value NOT in allowed list -> exits 1" {
  # Boolean false is now treated as a real value, so it must participate
  # in enum validation rather than being silently skipped as if absent.
  export VALUES='{"fail-fast":false}'
  export ENUMS='{"fail-fast":["true"]}'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fail-fast: must be one of"* ]]
  [[ "$output" == *"got 'false'"* ]]
}

@test "validate: pattern with boolean false -> does not match numeric regex (errors)" {
  # Boolean false is now a real string "false", so it participates in
  # pattern matching. The numeric regex must reject it.
  export VALUES='{"python-version":false}'
  export PATTERNS='{"python-version":"^[0-9]+\\.[0-9]+$"}'
  run bash "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"python-version: must match"* ]]
}

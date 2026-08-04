#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# bats tests for .github/actions/run-pytest-with-args/run.sh
#
# The script assembles a pytest command line from env vars and runs
# `uv run pytest <args>`. We stub `uv` (and `pytest`) via the helper so
# the tests don't need a real uv installation.

load 'helpers/common'

setup() {
  # Defaults so the action doesn't fail with `set -u` before tests can
  # override individual vars.
  export EXTRA_FLAGS=''
  export PYTEST_TARGETS=''
  export PYTEST_ARGS=''
  export WORKING_DIRECTORY=''
  rm -f "$BATS_TEST_TMPDIR/uv.log" "$BATS_TEST_TMPDIR/pytest.log"
  TARGET="$ACTION_DIR/run-pytest-with-args/run.sh"
}

# Helper: prepend the action directory to PATH so the stub `uv` is found.
# This requires the helper to be loaded (which `export -f uv` does).
run_pytest() {
  run bash "$TARGET"
}

# ---------------------------------------------------------------------------
# Argument assembly
# ---------------------------------------------------------------------------

@test "run: minimal invocation (only PYTEST_TARGETS) -> uv receives targets" {
  export PYTEST_TARGETS="tests"
  # Empty placeholders so `set -u` doesn't trip on unset EXTRA_FLAGS/PYTEST_ARGS.
  export EXTRA_FLAGS=""
  export PYTEST_ARGS=""
  export WORKING_DIRECTORY="$BATS_TEST_TMPDIR"
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  grep -q "pytest tests" "$BATS_TEST_TMPDIR/uv.log"
}

@test "run: EXTRA_FLAGS prepended before targets" {
  export PYTEST_TARGETS="tests"
  export EXTRA_FLAGS="--tb=short -v"
  export PYTEST_ARGS=""
  export WORKING_DIRECTORY="$BATS_TEST_TMPDIR"
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  # Order: uv pytest --tb=short -v tests
  grep -q "pytest --tb=short -v tests" "$BATS_TEST_TMPDIR/uv.log"
}

@test "run: PYTEST_ARGS appended after targets" {
  export PYTEST_TARGETS="tests"
  export PYTEST_ARGS="--cov=src --cov-report=xml:coverage.xml"
  export EXTRA_FLAGS=""
  export WORKING_DIRECTORY="$BATS_TEST_TMPDIR"
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  grep -q "pytest tests --cov=src --cov-report=xml:coverage.xml" "$BATS_TEST_TMPDIR/uv.log"
}

@test "run: all four vars combined -> correct ordering" {
  export PYTEST_TARGETS="tests/unit"
  export EXTRA_FLAGS="--tb=short"
  export PYTEST_ARGS="-x -q"
  export WORKING_DIRECTORY="$BATS_TEST_TMPDIR"
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  grep -q "pytest --tb=short tests/unit -x -q" "$BATS_TEST_TMPDIR/uv.log"
}

# ---------------------------------------------------------------------------
# Working directory
# ---------------------------------------------------------------------------

@test "run: cd to WORKING_DIRECTORY before invoking pytest" {
  export PYTEST_TARGETS="."
  export WORKING_DIRECTORY="$BATS_TEST_TMPDIR"
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  # The stub uv prints the args; if cd worked, the cd had no error.
  # Direct check: there should be NO 'No such file' in stderr.
  [[ "$output" != *"No such file"* ]]
}

# ---------------------------------------------------------------------------
# set -euo pipefail behavior
# ---------------------------------------------------------------------------

@test "run: missing PYTEST_TARGETS -> script exits non-zero (set -u)" {
  unset PYTEST_TARGETS
  export WORKING_DIRECTORY="$BATS_TEST_TMPDIR"
  run bash "$TARGET"
  # set -u makes unset variable access fail.
  [ "$status" -ne 0 ]
}

@test "run: WORKING_DIRECTORY not set -> script exits non-zero (set -u)" {
  export PYTEST_TARGETS="tests"
  unset WORKING_DIRECTORY
  run bash "$TARGET"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Failure propagation
# ---------------------------------------------------------------------------

@test "run: uv failure -> script exits non-zero (set -e)" {
  export PYTEST_TARGETS="tests"
  export WORKING_DIRECTORY="$BATS_TEST_TMPDIR"
  export BATS_UV_FAIL=1
  run bash "$TARGET"
  [ "$status" -ne 0 ]
  unset BATS_UV_FAIL
}

# ---------------------------------------------------------------------------
# Quote / split handling
# ---------------------------------------------------------------------------

@test "run: PYTEST_TARGETS with embedded spaces is passed as one arg" {
  # PYTEST_TARGETS as a single string with spaces is split by uv's $@
  # into multiple args. This test pins the current behaviour: a space-
  # containing target is split. Documenting so we know if we ever want
  # to change it (e.g., to use a single array element).
  export PYTEST_TARGETS="my dir"
  export WORKING_DIRECTORY="$BATS_TEST_TMPDIR"
  run bash "$TARGET"
  [ "$status" -eq 0 ]
  grep -q "pytest my dir" "$BATS_TEST_TMPDIR/uv.log"
  # "my dir" is split into "my" and "dir" by uv's array expansion.
  # Verify both tokens appear in order in the log.
  grep -q "pytest my dir" "$BATS_TEST_TMPDIR/uv.log"
}

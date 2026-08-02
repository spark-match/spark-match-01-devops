#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  ACTION_DIR="${REPO_ROOT}/.github/actions/bats-runner"
  ACTION_YML="${ACTION_DIR}/action.yml"
  INSTALL_SH="${ACTION_DIR}/install.sh"
  DISCOVER_SH="${ACTION_DIR}/discover.sh"
  RUN_SH="${ACTION_DIR}/run.sh"

  TEST_TEMP="$(mktemp -d)"
}

teardown() {
  if [ -n "${TEST_TEMP:-}" ] && [ -d "${TEST_TEMP}" ]; then
    rm -rf "${TEST_TEMP}"
  fi
  unset BATS_DIR
  unset BATS_VERSION
  unset DISCOVER_FILES
}

@test "action.yml exists at .github/actions/bats-runner/" {
  [ -f "$ACTION_YML" ]
}

@test "action.sh: not present (this action uses 3 small scripts)" {
  [ ! -f "${ACTION_DIR}/action.sh" ]
}

@test "install.sh exists and is executable" {
  [ -f "$INSTALL_SH" ]
  [ -x "$INSTALL_SH" ]
}

@test "discover.sh exists and is executable" {
  [ -f "$DISCOVER_SH" ]
  [ -x "$DISCOVER_SH" ]
}

@test "run.sh exists and is executable" {
  [ -f "$RUN_SH" ]
  [ -x "$RUN_SH" ]
}

@test "action.yml declares using: composite" {
  grep -qE '^[[:space:]]*using:[[:space:]]+composite' "$ACTION_YML"
}

@test "action.yml declares bats-version input with default 1.11.1" {
  grep -qE '^[[:space:]]+bats-version:' "$ACTION_YML"
  grep -A3 'bats-version:' "$ACTION_YML" | grep -q "default: '1.11.1'"
}

@test "action.yml declares bats-dir input with default tests/bats" {
  grep -qE '^[[:space:]]+bats-dir:' "$ACTION_YML"
  grep -A3 'bats-dir:' "$ACTION_YML" | grep -q "default: 'tests/bats'"
}

@test "action.yml declares outputs: count, files" {
  grep -qE '^[[:space:]]+count:' "$ACTION_YML"
  grep -qE '^[[:space:]]+files:' "$ACTION_YML"
}

@test "action.yml steps reference scripts via \$GITHUB_ACTION_PATH" {
  grep -qE '\$GITHUB_ACTION_PATH/install\.sh' "$ACTION_YML"
  grep -qE '\$GITHUB_ACTION_PATH/discover\.sh' "$ACTION_YML"
  grep -qE '\$GITHUB_ACTION_PATH/run\.sh' "$ACTION_YML"
}

@test "install.sh: uses strict mode (set -euo pipefail)" {
  run head -1 "$INSTALL_SH"
  [[ "$output" == *"#!/usr/bin/env bash"* ]]
  grep -qE '^set -euo pipefail' "$INSTALL_SH"
}

@test "install.sh: uses curl with --retry for transient failures" {
  grep -qE 'curl.*--retry [0-9]+' "$INSTALL_SH"
}

@test "install.sh: pins to a specific tag (v\${BATS_VERSION} in URL, not main)" {
  grep -qE 'bats-core/archive/refs/tags/v\$\{BATS_VERSION\}' "$INSTALL_SH"
}

@test "discover.sh: uses strict mode (set -euo pipefail)" {
  run head -1 "$DISCOVER_SH"
  [[ "$output" == *"#!/usr/bin/env bash"* ]]
  grep -qE '^set -euo pipefail' "$DISCOVER_SH"
}

@test "discover.sh: finds *.bats files (functional test)" {
  mkdir -p "${TEST_TEMP}/bats-dir/subdir"
  touch "${TEST_TEMP}/bats-dir/test1.bats"
  touch "${TEST_TEMP}/bats-dir/test2.bats"
  touch "${TEST_TEMP}/bats-dir/subdir/nested.bats"
  touch "${TEST_TEMP}/bats-dir/other.txt"

  BATS_DIR="${TEST_TEMP}/bats-dir" \
    GITHUB_OUTPUT="${TEST_TEMP}/github_output" \
    run bash "$DISCOVER_SH"

  [ "$status" -eq 0 ]
  grep -q '^count=2$' "${TEST_TEMP}/github_output"
}

@test "discover.sh: does not recurse into subdirectories (depth 1)" {
  mkdir -p "${TEST_TEMP}/bats-dir/subdir"
  touch "${TEST_TEMP}/bats-dir/top.bats"
  touch "${TEST_TEMP}/bats-dir/subdir/nested.bats"

  BATS_DIR="${TEST_TEMP}/bats-dir" \
    GITHUB_OUTPUT="${TEST_TEMP}/github_output" \
    run bash "$DISCOVER_SH"

  [ "$status" -eq 0 ]
  grep -q '^count=1$' "${TEST_TEMP}/github_output"
}

@test "discover.sh: empty directory produces count=0" {
  mkdir -p "${TEST_TEMP}/empty-dir"

  BATS_DIR="${TEST_TEMP}/empty-dir" \
    GITHUB_OUTPUT="${TEST_TEMP}/github_output" \
    run bash "$DISCOVER_SH"

  [ "$status" -eq 0 ]
  grep -q '^count=0$' "${TEST_TEMP}/github_output"
}

@test "run.sh: uses strict mode (set -euo pipefail)" {
  run head -1 "$RUN_SH"
  [[ "$output" == *"#!/usr/bin/env bash"* ]]
  grep -qE '^set -euo pipefail' "$RUN_SH"
}

@test "run.sh: uses ::group:: and ::endgroup:: for log collapsibility" {
  grep -q '::group::' "$RUN_SH"
  grep -q '::endgroup::' "$RUN_SH"
}

@test "run.sh: skips empty lines (defensive)" {
  grep -q '\[ -z "\$f" \] && continue' "$RUN_SH"
}

@test "workflow reusable-quality.yml uses the composite action (not inline bash)" {
  run grep -E 'uses:[[:space:]]+\./\.github/actions/bats-runner' \
    "${REPO_ROOT}/.github/workflows/reusable-quality.yml"
  [ "$status" -eq 0 ]
}

@test "workflow reusable-quality.yml does NOT contain 'BATS_VERSION' (no inline bash)" {
  run grep -E 'BATS_VERSION' "${REPO_ROOT}/.github/workflows/reusable-quality.yml"
  [ "$status" -ne 0 ]
}

@test "workflow reusable-quality.yml does NOT contain 'mapfile -t BATS_FILES' (no inline bash)" {
  run grep -E 'mapfile -t BATS_FILES' "${REPO_ROOT}/.github/workflows/reusable-quality.yml"
  [ "$status" -ne 0 ]
}
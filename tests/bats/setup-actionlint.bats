#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# setup-actionlint.bats - input validation for the setup-actionlint composite
#
# Scope: tests the parts that do NOT need network access (input gating,
# default install-dir behavior). The actual download from rhysd/actionlint
# is intentionally NOT mocked here - that path runs against the real
# network in CI. Mocks would mask supply-chain regressions.
# =============================================================================

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  ACTION_DIR="${REPO_ROOT}/.github/actions/setup-actionlint"
  INSTALL_SH="${ACTION_DIR}/install.sh"
  ACTION_YML="${ACTION_DIR}/action.yml"
}

@test "action.yml exists at .github/actions/setup-actionlint/" {
  [ -f "$ACTION_YML" ]
}

@test "install.sh exists at .github/actions/setup-actionlint/" {
  [ -f "$INSTALL_SH" ]
}

@test "install.sh is executable" {
  [ -x "$INSTALL_SH" ]
}

@test "action.yml declares using: composite" {
  run grep -E '^[[:space:]]*using:[[:space:]]+composite' "$ACTION_YML"
  [ "$status" -eq 0 ]
}

@test "action.yml declares required version input" {
  run grep -E '^[[:space:]]+version:' "$ACTION_YML"
  [ "$status" -eq 0 ]
}

@test "action.yml declares executable output" {
  run grep -E '^[[:space:]]+executable:' "$ACTION_YML"
  [ "$status" -eq 0 ]
}

@test "action.yml runs install.sh via \$GITHUB_ACTION_PATH (composite convention)" {
  run grep -E '\$GITHUB_ACTION_PATH/install\.sh' "$ACTION_YML"
  [ "$status" -eq 0 ]
}

@test "install.sh: fails with empty version and ::error:: annotation" {
  unset INPUT_VERSION
  unset INPUT_INSTALL_DIR
  run bash "$INSTALL_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"::error::version input is required"* ]]
}

@test "install.sh: fails with empty install-dir and ::error:: annotation" {
  INPUT_VERSION="1.7.12"
  unset INPUT_INSTALL_DIR
  run bash "$INSTALL_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"::error::install-dir input is required"* ]]
}

@test "install.sh: sets set -euo pipefail (strict mode)" {
  run head -1 "$INSTALL_SH"
  [[ "$output" == *"#!/usr/bin/env bash"* ]]
  run grep -E '^set -euo pipefail' "$INSTALL_SH"
  [ "$status" -eq 0 ]
}

@test "install.sh: pins to a specific tag (v\${version} in URL, not main)" {
  run grep -E 'raw\.githubusercontent\.com/rhysd/actionlint/v\$\{version\}' "$INSTALL_SH"
  [ "$status" -eq 0 ]
}

@test "install.sh: uses curl with --retry for transient failures" {
  run grep -E 'curl.*--retry [0-9]+' "$INSTALL_SH"
  [ "$status" -eq 0 ]
}

@test "install.sh: validates binary is executable before declaring success" {
  run grep -E 'if \[\[ ! -x "\$executable"' "$INSTALL_SH"
  [ "$status" -eq 0 ]
}

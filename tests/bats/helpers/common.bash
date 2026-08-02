#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# Common helpers for bats tests in this directory.
#
# Provides:
#   ACTION_DIR  - absolute path to .github/actions
#   REPO_ROOT   - absolute path to repo root (parent of .github)
#
# Usage in a .bats file:
#   load '../helpers/common'
#
# Then reference $ACTION_DIR/validate-workflow-inputs/validate.sh etc.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTION_DIR="$REPO_ROOT/.github/actions"

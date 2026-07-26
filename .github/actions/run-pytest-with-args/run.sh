#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
set -euo pipefail

args=()

if [ -n "$EXTRA_FLAGS" ]; then
  # shellcheck disable=SC2206
  flags=($EXTRA_FLAGS)
  args+=("${flags[@]}")
fi

args+=("$PYTEST_TARGETS")

if [ -n "$PYTEST_ARGS" ]; then
  # shellcheck disable=SC2206
  extra=($PYTEST_ARGS)
  args+=("${extra[@]}")
fi

cd "$WORKING_DIRECTORY"
uv run pytest "${args[@]}"

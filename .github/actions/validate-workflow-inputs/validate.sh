#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
set -euo pipefail

ERRORS=()

# Required
if [ -n "$REQUIRED" ]; then
  IFS='|' read -ra names <<< "$REQUIRED"
  for k in "${names[@]}"; do
    v=$(echo "$VALUES" | jq -r --arg k "$k" '.[$k] // ""')
    if [ -z "$v" ] || [ "$v" = "null" ]; then
      ERRORS+=("$k: required")
    fi
  done
fi

# Enums
if [ -n "$ENUMS" ] && [ "$ENUMS" != "{}" ]; then
  for k in $(echo "$ENUMS" | jq -r 'keys[]'); do
    v=$(echo "$VALUES" | jq -r --arg k "$k" '.[$k] // ""')
    if [ -n "$v" ] && [ "$v" != "null" ]; then
      if [ "$(echo "$ENUMS" | jq -r --arg k "$k" --arg v "$v" '.[$k] | index($v) // -1')" = "-1" ]; then
        allowed=$(echo "$ENUMS" | jq -r --arg k "$k" '.[$k] | join(", ")')
        ERRORS+=("$k: must be one of [$allowed], got '$v'")
      fi
    fi
  done
fi

# Patterns
if [ -n "$PATTERNS" ] && [ "$PATTERNS" != "{}" ]; then
  for k in $(echo "$PATTERNS" | jq -r 'keys[]'); do
    v=$(echo "$VALUES" | jq -r --arg k "$k" '.[$k] // ""')
    pat=$(echo "$PATTERNS" | jq -r --arg k "$k" '.[$k]')
    if [ -n "$v" ] && [ "$v" != "null" ] && ! [[ "$v" =~ $pat ]]; then
      ERRORS+=("$k: must match /$pat/, got '$v'")
    fi
  done
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "::error::Input validation failed:"
  for E in "${ERRORS[@]}"; do echo "::error::  - $E"; done
  exit 1
fi

echo "All inputs validated"

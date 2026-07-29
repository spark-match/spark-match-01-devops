#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
set -euo pipefail

ERRORS=()

# Resolve a value as a string for downstream checks.
# NOTE: jq's `//` is the "alternative" operator and fires on BOTH null and
# false. Boolean false / numeric 0 are valid values that callers may pass
# intentionally, so we must distinguish "missing or null" from "present
# and falsy". The expression below returns "" ONLY when the key is absent
# or the value is JSON null; boolean false and numeric 0 round-trip as
# their string forms ("false" and "0").
resolve_value() {
  local k="$1"
  echo "$VALUES" | jq -r --arg k "$k" \
    'if has($k) and .[$k] != null then .[$k] | tostring else "" end'
}

# Required
if [ -n "$REQUIRED" ]; then
  IFS='|' read -ra names <<< "$REQUIRED"
  for k in "${names[@]}"; do
    v=$(resolve_value "$k")
    if [ -z "$v" ]; then
      ERRORS+=("$k: required")
    fi
  done
fi

# Enums
if [ -n "$ENUMS" ] && [ "$ENUMS" != "{}" ]; then
  for k in $(echo "$ENUMS" | jq -r 'keys[]'); do
    v=$(resolve_value "$k")
    if [ -n "$v" ]; then
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
    v=$(resolve_value "$k")
    pat=$(echo "$PATTERNS" | jq -r --arg k "$k" '.[$k]')
    if [ -n "$v" ] && ! [[ "$v" =~ $pat ]]; then
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

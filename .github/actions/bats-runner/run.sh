#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "::group::$f"
  bats "$f"
  echo "::endgroup::"
done <<< "${DISCOVER_FILES}"
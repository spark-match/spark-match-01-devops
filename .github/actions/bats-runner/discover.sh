#!/usr/bin/env bash
set -euo pipefail

BATS_DIR="${BATS_DIR:-tests/bats}"

mapfile -t BATS_FILES < <(find "${BATS_DIR}" -maxdepth 1 -type f -name '*.bats' | sort)

echo "count=${#BATS_FILES[@]}" >> "$GITHUB_OUTPUT"

if [ "${#BATS_FILES[@]}" -gt 0 ]; then
  {
    echo "files<<EOF"
    printf '%s\n' "${BATS_FILES[@]}"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
else
  echo "files=" >> "$GITHUB_OUTPUT"
fi
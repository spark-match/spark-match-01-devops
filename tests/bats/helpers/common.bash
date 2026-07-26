#!/usr/bin/env bash
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

# Stub `uv` for run-pytest-with-args tests so we don't actually need uv.
# Records each invocation to $BATS_TEST_TMPDIR/uv.log and returns 0 unless
# the test sets BATS_UV_FAIL=1.
uv() {
  echo "$@" >>"$BATS_TEST_TMPDIR/uv.log"
  if [ "${BATS_UV_FAIL:-0}" = "1" ]; then
    return 1
  fi
  return 0
}
export -f uv

# Stub `pytest` too, since `uv run pytest` resolves to a child process.
pytest() {
  echo "pytest $*" >>"$BATS_TEST_TMPDIR/pytest.log"
  return 0
}
export -f pytest

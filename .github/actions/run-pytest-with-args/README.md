# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match

# `run-pytest-with-args`

Composite action that wraps `uv run pytest` with safe argument splitting
and a configurable working directory. Designed for any caller recipe that
needs to run pytest in a pinned Python project.

## Inputs

| Input | Type | Required | Default | Description |
|---|---|---|---|---|
| `pytest-targets` | string | no | `tests` | Path passed to pytest (e.g. `tests`, `tests/python`). |
| `pytest-args` | string | no | `''` | Extra pytest args appended after the targets (e.g. `--cov=src --cov-report=xml:coverage.xml`). |
| `working-directory` | string | no | `.` | Working directory for the pytest invocation. |
| `extra-flags` | string | no | `--tb=short` | Extra pytest CLI flags prepended before targets/args (e.g. `-v`, `-x`). |

> **Note**: `type: string` on composite-action inputs is silently ignored
> by GitHub Actions — only `description` / `required` / `default` /
> `deprecationMessage` are honored. Inputs are always strings at runtime;
> callers wanting typed values should validate via
> `validate-workflow-inputs`.

## Behavior

- Sets `set -euo pipefail` (via `run.sh`).
- Splits `EXTRA_FLAGS` and `PYTEST_ARGS` on whitespace (intentional
  word-splitting; targets/args with embedded spaces are passed as one
  token, see tests).
- `cd`s to `WORKING_DIRECTORY` before invoking `uv run pytest`.
- Missing `PYTEST_TARGETS` or `WORKING_DIRECTORY` aborts with non-zero
  exit (`set -u`).

The final command shape:

```
uv run pytest ${EXTRA_FLAGS} ${PYTEST_TARGETS} ${PYTEST_ARGS}
```

## Usage

```yaml
steps:
  - name: Run tests
    uses: spark-match/spark-match-01-devops/.github/actions/run-pytest-with-args@main
    env:
      PYTEST_TARGETS: tests
      EXTRA_FLAGS: --tb=short -v
      PYTEST_ARGS: --cov=src
      WORKING_DIRECTORY: ${{ inputs.working-directory }}
    with:
      pytest-targets: tests
      pytest-args: --cov=src --cov-report=xml:coverage.xml
      working-directory: .
      extra-flags: --tb=short
```

## Tests

- `tests/bats/composite-run-pytest.bats` (9 cases) — argument ordering,
  working-directory cd, `set -u` on unset vars, uv failure propagation,
  embedded spaces in targets.

## License

GPL-3.0-or-later. See repository root `LICENSE`.
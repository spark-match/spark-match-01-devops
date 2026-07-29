# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match

# `validate-workflow-inputs`

Composite action that gates a workflow step on the validity of its
inputs. Reads three constraint families (REQUIRED, ENUMS, PATTERNS) and
emits a single `::error::` block listing every violation. Fails fast
so downstream steps don't see confusing errors caused by bad inputs.

## Inputs

| Input | Type | Required | Default | Description |
|---|---|---|---|---|
| `values` | string | yes | (none) | JSON object mapping input name to its current value (e.g. `{"project-key":"abc","env":"dev"}`). |
| `required` | string | no | `''` | Pipe-separated list of input names that must be non-empty. Empty = skip REQUIRED checks. |
| `enums` | string | no | `{}` | JSON object of input name to allowed-values array. Empty object = skip ENUM checks. |
| `patterns` | string | no | `{}` | JSON object of input name to regex pattern. Uses bash `[[ =~ ]]`. Empty object = skip PATTERN checks. |

> **Note**: `type: string` on composite-action inputs is silently
> ignored by GitHub Actions (only `description` / `required` / `default`
> are honored). Inputs are always strings; validation semantics depend
> on the action's `validate.sh` logic.

## Behavior

- Sets `set -euo pipefail` (via `validate.sh`).
- Collects all errors (does NOT fail-fast on the first).
- Exits 0 on success, 1 on validation failure.
- JSON boolean `false` and numeric `0` are valid values
  (not coerced to missing); only JSON `null` or a missing key is
  treated as "no value".

Exit code contract:

- `0` — all constraints satisfied.
- `1` — at least one input violated a constraint; the violations are
  listed as `::error::  - <name>: <reason>` annotations.

## Usage

```yaml
steps:
  - name: Validate inputs
    uses: spark-match/spark-match-01-devops/.github/actions/validate-workflow-inputs@main
    with:
      values: |
        {"environment-name": "${{ inputs.environment-name }}",
         "shellcheck-severity": "${{ inputs.shellcheck-severity }}"}
      enums: |
        {"shellcheck-severity": ["warning", "error", "info", "style"]}
      required: 'environment-name'
      patterns: |
        {"environment-name": "^[a-z][a-z0-9-]{1,30}$"}
```

## Tests

- `tests/bats/composite-validate.bats` (24 cases) — required present /
  missing / null / empty / boolean false / numeric 0, enum match /
  mismatch / empty / boolean membership, pattern match / mismatch /
  empty, malformed JSON, exit-code contract, all-three combined.

## License

GPL-3.0-or-later. See repository root `LICENSE`.
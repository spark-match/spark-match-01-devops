# Python CI reusable (`python-ci.yml`)

> **Owner**: `spark-match/spark-match-01-devops` (layer: `python/`)
> **Status**: Recipe v3.1+ — covers uv + ruff + mypy + pytest + coverage upload
> **Audience**: maintainers of Python projects that use `uv` for dependency
> management and want a single reusable QA gate.

This document is the canonical reference for the reusable workflow
`spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@<branch>`.
It complements `docs/VERSIONING.md` (governance + pin-by-environment model)
and `docs/CACHE.md` (cross-ecosystem cache key convention).

---

## 1. Summary

`python-ci.yml` is a `workflow_call` reusable that runs a Python project
QA pipeline using `uv` + `ruff` + `mypy` + `pytest`. It is designed for
projects whose dependency layout matches the orion-cognitive-agent
convention:

- A `.python-version` pin (consumed by `uv python install`).
- A `pyproject.toml` with `[project]` + `[dependency-groups]`.
- An optional `uv.lock` (recommended; required if any caller passes
  `lock-check: true`, see the Sprint B backlog).
- Source under `src/<package>/` (or whatever `ruff-targets` /
  `mypy-targets` point at).
- Tests under `tests/`.

The recipe is **generic** beyond those conventions: it does not assume a
specific project layout beyond `pyproject.toml` existing inside
`working-directory`. Callers point at any subdirectory that holds a
valid `pyproject.toml`.

The recipe does **not** deploy or publish. It is a static-analysis +
test gate. Deploy reusables live under `deploy/` (out of scope).

---

## 2. Use cases

| Caller | Layout | Invocation pattern |
|---|---|---|
| `ahincho/orion-cognitive-agent` | monorepo, single `pyproject.toml`, dependency group `bedrock` is runtime-only | `dependency-groups: dev bedrock` |
| `spark-match/spark-match-08-deep-agent` | placeholder — to be wired up when the project's CI migrates from legacy `pip` to `uv` | `dependency-groups: dev` |
| `spark-match/spark-match-01-devops` itself (self-test, Sprint D) | `tests/fixtures/python-project/` with two custom groups (`dev`, `lint`) | `working-directory: tests/fixtures/python-project`, `dependency-groups: dev lint` |

If you have a new Python caller, copy the row that most resembles your
layout and confirm the recipe runs locally with
`act -W .github/workflows/python-ci.yml -e .env` before opening the PR.

---

## 3. Inputs

| Input | Type | Required | Default | Notes |
|---|:---:|:---:|---|---|
| `environment-name` | string | yes | — | Job name suffix + optional GH Environment gate. Conventions: `ci` (PR gate), `dev` (post-merge on `dev` branch), `prod` (post-merge on `main`/release). |
| `python-versions` | string (JSON list) | no | `"3.12"` | JSON list passed to `fromJSON()` to build the matrix. Examples: `'"3.12"'`, `'"3.11","3.12"'`, `'"3.10","3.11","3.12","3.13"'`. |
| `working-directory` | string | no | `.` | Path containing `pyproject.toml` (relative to repo root). For monorepos or fixture invocations. |
| `commands` | CSV string | no | `lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest,coverage:upload` | Ordered subset of pipeline steps. Use `none` to opt out of all automatic steps (rare). See § 5. |
| `dependency-groups` | string (space-separated tokens) | no | `dev` | Extra `uv sync --group` groups. Examples: `dev bedrock`, `dev lint`, `dev bedrock market`. Empty = `uv sync` (no groups). |
| `ruff-targets` | CSV string | no | `src tests` | Passed to `ruff format --check` and `ruff check`. |
| `mypy-targets` | CSV string | no | `src` | Passed to `mypy`. |
| `pytest-targets` | string | no | `tests` | Passed to `pytest` (single path; multi-path support is on the backlog). |
| `coverage-output` | string | no | `coverage.xml` | Path under `working-directory` uploaded as a job artifact. |
| `setup-uv-version` | string | no | `latest` | Pinned in `astral-sh/setup-uv@v6`. Use a specific version for reproducibility (`0.11.2`, etc.). |
| `cache-suffix` | string | no | `""` (derived) | Suffix for the GH Actions cache key. Default (empty) makes the recipe fall back to `environment-name`. Set explicitly only for finer partition. See `docs/VERSIONING.md` § "Cache semantics" and `docs/CACHE.md` § 1. |
| `timeout-minutes` | number | no | `20` | Job-level timeout. Increase for slow coverage suites. |
| `fail-fast` | boolean | no | `false` | `strategy.matrix.fail-fast`. Flip on for fast-fail on multi-version callers. |

### Input validation

The recipe runs a `Validate inputs` step before any other work. It bails
out with `::error::` annotations if `environment-name`,
`working-directory` or `python-versions` are empty, or if `commands`
contains an unknown pipeline step. This keeps caller-side mistakes from
producing confusing later errors.

---

## 4. Cache key formula

The recipe uses `astral-sh/setup-uv@v6`'s built-in cache, scoped by:

```
cache-key = setup-uv-ubuntu-latest-<cache-suffix>-<sha256(pyproject.toml + uv.lock)>
```

where `<cache-suffix>` defaults to `${{ inputs.environment-name }}` when
the input is empty, and is recommended to be set explicitly to
`${{ inputs.environment-name }}-${{ inputs.python-versions }}` for
multi-Python-version callers.

`cache-dependency-glob` is:

```
${{ inputs.working-directory }}/pyproject.toml
${{ inputs.working-directory }}/uv.lock
```

The hash is recomputed on every run; missing `uv.lock` is treated as
empty bytes (so callers without a lockfile still get a usable cache key,
just one that invalidates whenever `pyproject.toml` changes).

For the full cross-ecosystem convention (node, terraform, etc.) see
`docs/CACHE.md` § 1. For the rationale (per-environment +
per-Python-version + per-project isolation) see `docs/VERSIONING.md`
§ "Cache semantics".

---

## 5. Valid pipeline commands

The `commands` input is an ordered CSV. Steps run in the order listed.

| Command | Purpose | Underlying call |
|---|---|---|
| `lint:ruff-format` | Verify formatting | `uv run ruff format --check <ruff-targets>` |
| `lint:ruff-check` | Static lint (rules) | `uv run ruff check <ruff-targets>` |
| `typecheck:mypy` | Static type check | `uv run mypy <mypy-targets>` |
| `test:pytest` | Unit tests | `uv run pytest --tb=short <pytest-targets>` |
| `coverage:upload` | Artifact upload of `<coverage-output>` | `actions/upload-artifact@v4`, always-run (uses `if: always()`) so partial failures still produce the artifact |
| `none` | Opt out of all automatic steps | Manual `uv run ...` only |

Unknown commands bail out in `Validate inputs` with the list of allowed
values. This is intentional: silent step skipping caused several Sprint 0
issues where `lock:check` was spelled differently across callers.

---

## 6. Required secrets / environments

The recipe has **no required secrets** — it is an ecosystem-style QA
recipe. Coverage upload uses `actions/upload-artifact@v4` which does not
require any token beyond the default `GITHUB_TOKEN`.

`environment-name` may match a GH Environment that has optional
protection rules (required reviewers, wait timer, etc.). If no matching
environment exists in the caller repo, the `environment:` job property
is a no-op and the run proceeds without gating.

---

## 7. Caller patterns

### 7.1 Canonical: orion-cognitive-agent (single Python, single env)

```yaml
# .github/workflows/ci-python.yml
name: Python CI

on:
  pull_request:
    branches: [main, dev]
    types: [opened, synchronize, reopened]
  push:
    branches: [main, dev]

permissions:
  contents: read

concurrency:
  group: ci-python-${{ github.ref }}
  cancel-in-progress: true

jobs:
  qa:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@main
    with:
      environment-name: ci
      python-versions: '"3.12"'
      working-directory: .
      commands: lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest,coverage:upload
      dependency-groups: dev bedrock
```

### 7.2 Multi-Python matrix with fail-fast

```yaml
jobs:
  qa:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@dev
    with:
      environment-name: ci
      python-versions: '"3.11","3.12","3.13"'
      working-directory: .
      commands: lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest
      dependency-groups: dev
      cache-suffix: ${{ inputs.environment-name }}-${{ inputs.python-versions }}
      timeout-minutes: 30
      fail-fast: true
```

### 7.3 Self-test: invoke on a fixture inside the same repo (Sprint D pattern)

```yaml
# .github/workflows/ci.yml — self-test of python-ci.yml itself
jobs:
  python-qa-self-test:
    name: "Python QA (self-test)"
    uses: ./.github/workflows/python-ci.yml
    with:
      environment-name: ci
      python-versions: '"3.11","3.12"'
      working-directory: tests/fixtures/python-project
      commands: lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest,coverage:upload
      dependency-groups: dev lint
```

This pattern is what `spark-match-01-devops/.github/workflows/ci.yml`
runs on every PR. The fixture (`tests/fixtures/python-project/`) is a
two-module, three-test dummy project with `dev` + `lint` dependency
groups; it exists solely to dogfood the recipe.

---

## 8. Known limitations / backlog

These are tracked in `PENDIENTES-CI-CD.md` and explicitly **not**
implemented yet:

- `pytest-args` (extra flags like `-n auto`, `--maxfail=1 -p no:cacheprovider`) — Sprint B.
- `coverage-threshold` (fail under `coverage report --fail-under=N`) — Sprint B.
- `permissions-write` opt-in for sticky PR comments with coverage delta — Sprint B.
- `lock-check` (`uv lock --check` before sync) — Sprint B.
- `frozen` (`uv sync --frozen` for prod callers) — Sprint B.
- `pip-audit` extra command — Sprint B.
- `sync-mode` input ∈ {full, runtime-only, lint-only} — Sprint C.
- `actions/checkout@v8` bump — separate track.

Once Sprint B lands, this document should be extended with the new
inputs (mirror the table in § 3).

---

## 9. Versioning + promotion model

This recipe follows the **pin-by-environment** model described in
`docs/VERSIONING.md`:

- Dev / staging callers pin `@dev`.
- Prod callers pin `@main`.
- Changes land via PR against `dev`, are smoke-tested by a canonical
  caller (`orion-cognitive-agent@dev`), then promoted to `main` via a
  chore PR.

Self-test enhancement (this Sprint D) is exactly what makes the
"smoke-tested by orion-cognitive-agent" gate redundant for purely
recipe-internal changes — the in-repo fixture catches regressions
before any external caller runs. External callers are still the source
of truth for *caller-specific* layout quirks.

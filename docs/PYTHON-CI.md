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

Grouped by concern. Defaults tuned for `orion-cognitive-agent`; callers
override as needed.

### 3.1 Core

| Input | Type | Required | Default | Notes |
|---|:---:|:---:|---|---|
| `environment-name` | string | yes | — | Job name suffix + optional GH Environment gate. |
| `working-directory` | string | no | `.` | Path containing `pyproject.toml` (and optional `uv.lock`). |
| `commands` | CSV string | no | `lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest,coverage:upload` | Ordered subset of pipeline steps. See § 5. `none` opts out of all automatic steps. |
| `dependency-groups` | string (space-separated) | no | `dev` | Extra `uv sync --group` groups. For security commands add `security`. |
| `runs-on` | string | no | `ubuntu-latest` | Runner label. Override for windows/macos/arm64 callers (`windows-latest`, `macos-latest`, `ubuntu-24.04-arm`). |
| `timeout-minutes` | number | no | `20` | Job-level timeout. Increase for slow coverage suites. |
| `fail-fast` | boolean | no | `false` | `strategy.matrix.fail-fast`. |

### 3.2 Pipeline scopes

| Input | Type | Required | Default | Notes |
|---|:---:|:---:|---|---|
| `ruff-targets` | CSV string | no | `src tests` | Passed to `ruff format/check[/--fix]`. |
| `mypy-targets` | CSV string | no | `src` | Passed to `mypy`. |
| `pytest-targets` | string | no | `tests` | First positional arg of `pytest`. |
| `setup-uv-version` | string | no | `latest` | Pinned in `astral-sh/setup-uv@v6`. |
| `cache-suffix` | string | no | `""` (derived) | Cache key suffix; falls back to `environment-name`. See § 4 + `docs/VERSIONING.md`. |

### 3.3 Coverage + reporting (Sprint B)

| Input | Type | Required | Default | Notes |
|---|:---:|:---:|---|---|
| `coverage-output` | string | no | `coverage.xml` | Path under `working-directory` uploaded as an artifact. |
| `pytest-args` | string | no | `""` | Free-form args appended after `pytest --tb=short <pytest-targets>`. Example: `'-n auto -p no:cacheprovider'`. For coverage data, add `--cov=<pkg> --cov-report=xml:<coverage-output>`. |
| `coverage-threshold` | string | no | `""` | Numeric threshold (e.g. `"80"` or `"75.5"`) enforced via `coverage report --fail-under=N`. Empty disables. Requires `.coverage` to exist (caller adds `--cov` to `pytest-args`). |
| `permissions-write` | boolean | no | `false` | Opt-in sticky PR coverage comment via `marocchino/sticky-pull-request-comment@v2`. The recipe grants `pull-requests: write` at the workflow level; if `permissions-write` is `false` (default) the step is skipped. |

### 3.4 Sync flags (Sprint B)

| Input | Type | Required | Default | Notes |
|---|:---:|:---:|---|---|
| `lock-check` | boolean | no | `false` | Drift detector: runs `uv lock --check` before sync. Exits non-zero if `uv.lock` is out of date relative to `pyproject.toml`. |
| `frozen` | boolean | no | `false` | Pass `--frozen` to `uv sync` (no lock regeneration). Recommended for prod callers. Pairs naturally with `lock-check: true`. |

### Input validation

The recipe runs a `Validate inputs` step before any other work. It bails
out with `::error::` annotations if:

- `environment-name`, `working-directory`, or `runs-on` are empty.
- `coverage-threshold` is set but non-numeric.
- `permissions-write`, `lock-check`, or `frozen` is not `"true"`/`"false"`.
- `commands` contains an unknown pipeline step.

This keeps caller-side mistakes from producing confusing later errors.

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
Commands are grouped by concern; commands within a group are mutually
exclusive alternatives unless noted (e.g. `lint:ruff-format` and
`lint:ruff-format-fix` are alternatives — never use both at once).

### 5.1 Format / lint / typecheck

| Command | Purpose | Underlying call |
|---|---|---|
| `lint:ruff-format` | Verify formatting | `uv run ruff format --check <ruff-targets>` |
| `lint:ruff-format-fix` | Apply formatting (mutates files; **no commit**) | `uv run ruff format <ruff-targets>` |
| `lint:ruff-check` | Static lint (rules) | `uv run ruff check <ruff-targets>` |
| `lint:ruff-check-fix` | Apply safe autofixes (mutates files; **no commit**) | `uv run ruff check --fix <ruff-targets>` |
| `lint:bandit` | Security linter (B101 skipped by default) | `uv run bandit --recursive <ruff-targets> --skip B101` |
| `typecheck:mypy` | Static type check | `uv run mypy <mypy-targets>` |

### 5.2 Tests + coverage

| Command | Purpose | Underlying call |
|---|---|---|
| `test:pytest` | Unit tests | `uv run pytest --tb=short <pytest-targets> <pytest-args>` |
| `coverage:upload` | Upload `<coverage-output>` artifact | `actions/upload-artifact@v4`, `if: always()` |

### 5.3 Lockfile + security

| Command | Purpose | Underlying call |
|---|---|---|
| `lock:check` | Drift detector between `pyproject.toml` and `uv.lock` | `uv lock --check` |
| `security:pip-audit` | Audit transitive deps for known vulnerabilities | `uv run pip-audit --strict` |

### 5.4 Escape hatch

| Command | Purpose | Notes |
|---|---|---|
| `none` | Opt out of all automatic steps | Reserved for callers who want only manual `uv run ...` steps in addition to the recipe's required Validate / Checkout / Install uv / Set up Python. |

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
      working-directory: .
      commands: lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest,coverage:upload
      dependency-groups: dev bedrock
```

### 7.2 Multi-Python matrix with fail-fast (post-upstream-fix)

```yaml
jobs:
  qa:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@dev
    with:
      environment-name: ci
      # python-versions: '"3.11","3.12","3.13"'  # uncomment post GHA-bug-fix
      working-directory: .
      commands: lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest
      dependency-groups: dev
      cache-suffix: ${{ inputs.environment-name }}
      timeout-minutes: 30
      fail-fast: true
```

### 7.3 Sprint B security-heavy caller

```yaml
# Caller that runs pip-audit + bandit on every PR.
jobs:
  qa:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@main
    with:
      environment-name: ci
      working-directory: .
      commands: lint:ruff-format,lint:ruff-check,lint:bandit,lock:check,typecheck:mypy,test:pytest,coverage:upload,security:pip-audit
      dependency-groups: dev security
      lock-check: true
      pytest-args: '-p no:cacheprovider'
      coverage-output: cobertura.xml
      coverage-threshold: '85'
```

The caller's `[dependency-groups]` MUST include `security` when `security:pip-audit`
or `lint:bandit` are in `commands`, otherwise those steps fail with
`command not found`.

### 7.4 Sprint B prod caller with frozen sync

```yaml
jobs:
  qa:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@main
    with:
      environment-name: prod
      working-directory: .
      commands: lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest
      dependency-groups: dev bedrock
      lock-check: true
      frozen: true
      timeout-minutes: 30
```

`lock-check: true` verifies the locked dep set is still coherent; `frozen: true`
prevents the post-deploy install from regenerating `uv.lock` (caller is expected
to have already promoted the lockfile).

### 7.5 Self-test: invoke on a fixture inside the same repo (Sprint D pattern)

```yaml
# .github/workflows/ci.yml — self-test of python-ci.yml itself
jobs:
  python-qa-self-test:
    name: "Python QA (self-test)"
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@main
    with:
      environment-name: ci
      # python-versions intentionally omitted: the shipping recipe hardcodes
      # the Python matrix to "3.12" because of the upstream GHA bug
      # (strategy.matrix cannot reference inputs.* on cross-owner workflow_call;
      # see DIAGNOSTICO-GHA-MATRIX-CROSSOWNER.md). The self-test therefore
      # exercises the single-version variant.
      working-directory: tests/fixtures/python-project
      commands: lint:ruff-format,lint:ruff-check,lock:check,typecheck:mypy,test:pytest,coverage:upload,lint:bandit,security:pip-audit
      dependency-groups: dev lint security
      lock-check: true
      frozen: true
      ruff-targets: example tests
      mypy-targets: example
      pytest-targets: tests
```

This pattern is what `spark-match-01-devops/.github/workflows/ci.yml`
runs on every PR. The fixture (`tests/fixtures/python-project/`) is a
two-module, three-test dummy project with `dev`, `lint`, and `security`
dependency groups; it exists solely to dogfood the recipe. The `lock-check` and
`frozen` inputs are exercised on the fixture (which has a real `uv.lock`)
to validate those features each PR.

---

## 8. Known limitations / backlog

These are tracked in `PENDIENTES-CI-CD.md`.

### 8.0 Already shipped (Sprint B)

- `pytest-args` (free-form pytest flags) — see § 3.3.
- `coverage-threshold` (`coverage report --fail-under=N`) — see § 3.3.
- `permissions-write` (sticky PR coverage comment opt-in) — see § 3.3 + § 5.2.
- `lock-check` (`uv lock --check` drift detector) — see § 3.4.
- `frozen` (`uv sync --frozen` for prod callers) — see § 3.4.
- `runs-on` (override runner label for windows/macos/arm64) — see § 3.1.
- `security:pip-audit` command — see § 5.3.
- `lint:bandit` command — see § 5.1.
- `lint:ruff-format-fix` / `lint:ruff-check-fix` commands (mutating, no commit) — see § 5.1 + § 8.2.
- `lock:check` command (alias for the `lock-check: true` input) — see § 5.3.

### 8.1 Still pending (Sprint C / separate)

- `sync-mode` input ∈ {full, runtime-only, lint-only} — Sprint C.
- `actions/checkout@v8` bump — separate track.
- `runner-images`-preset for ARM64 — separate track.

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

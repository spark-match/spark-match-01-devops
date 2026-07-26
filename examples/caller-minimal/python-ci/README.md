# python-ci

Demonstrates the minimum caller for `python-ci.yml`. This is the canonical
QA pipeline for a Python project: ruff format + ruff check, mypy type
check, pytest, optional bandit + pip-audit, and a coverage artifact.

## What this example covers

- `uses:` line with `@main` (per the catalog's pin-by-main rule).
- `permissions:` re-declared to `contents: read` (minimum scope; no
  write permissions needed for QA).
- `environment-name: ci` (the recipe's job name will use this; it does
  NOT require a GitHub Environment to be configured for ecosystem/python
  recipes).
- The 19-input surface of `python-ci.yml` is documented in
  `docs/PYTHON-CI.md`. This example uses ALL defaults.

## What you must change to make it yours

1. **`working-directory`** if your `pyproject.toml` + `uv.lock` are not
   at the repo root.
2. **`dependency-groups`** to add the groups your project uses
   (`dev bedrock` if you have a `bedrock` group).
3. **`commands`** to remove steps you don't need (e.g. drop
   `security:pip-audit` if you use Dependabot-only).
4. **`pytest-targets`** if your tests live under a different path.
5. **`coverage-threshold`** once you have baseline coverage; leave
   empty in the first iteration.

## Required secrets

None. python-ci.yml is ecosystem-style; no AWS, no OIDC.

## Permissions matrix

This caller workflow grants only `contents: read`. python-ci.yml does
not request additional permissions.

If you opt into `permissions-write: true` to enable the sticky PR
coverage comment, the workflow will request `pull-requests: write`
for itself; the caller's permission is unchanged.

## Expected run time

~3 min on a typical Python project (uv sync + ruff + mypy + pytest).
With bandit + pip-audit enabled: ~4-5 min.

## Where to look in this repo

- `docs/PYTHON-CI.md` — full input catalog + design notes for the recipe.
- `README.md` § Catalog → python — high-level recipe description.

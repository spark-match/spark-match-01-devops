# example-fixture

Minimal Python project used by `spark-match/spark-match-01-devops`'s
self-test workflow `ci.yml` (job `python-qa-self-test`). It
dogfoods the recipe `python-ci.yml` end-to-end against an in-repo
project, so recipe changes can be validated without an external
caller.

## Layout

```
.
+-- example/                # importable package (runtime code)
|   +-- __init__.py
|   +-- calc.py
|   +-- greet.py
+-- tests/                  # pytest test suite
|   +-- test_calc.py
|   +-- test_greet.py
+-- pyproject.toml          # [project] + [dependency-groups] dev,lint
+-- uv.lock                 # generated; pinned versions
```

## Dependency groups

| Group | Purpose | Pinned packages |
|---|---|---|
| `dev` | Test + type check | `pytest`, `pytest-cov`, `mypy` |
| `lint` | Static lint + format | `ruff` |

The self-test invocation:

```
dependency-groups = dev lint
```

If you ever fork this fixture for a custom recipe smoke, keep the two
groups split so the recipe's `dependency-groups` parsing is exercised
against multiple tokens.

## Local reproduction

```bash
uv lock --group dev --group lint
uv sync --group dev --group lint
uv run ruff format --check example tests
uv run ruff check example tests
uv run mypy example
uv run pytest --tb=short tests
```

Coverage is generated as `coverage.xml` at the project root; the recipe
uploads it as an artifact named `coverage-py<version>`.

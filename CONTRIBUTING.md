# Contributing to `spark-match-01-devops`

Thank you for your interest in contributing to the Spark Match DevOps catalog. This document explains how to set up your environment, what conventions to follow, and how to open a pull request.

> **Note**: this is a **single-branch, single-purpose** repository. Changes go directly to `main` via pull request; there is no `dev` branch and no release pipeline. Read [Architecture](#architecture) and [Branch model](#branch-model) before opening a PR.

## Table of contents

- [Code of conduct](#code-of-conduct)
- [Architecture](#architecture)
- [Branch model](#branch-model)
- [Local setup](#local-setup)
- [Running tests](#running-tests)
- [Style and conventions](#style-and-conventions)
- [Pull request workflow](#pull-request-workflow)
- [Admin bypass (rare)](#admin-bypass-rare)
- [Adding a recipe](#adding-a-recipe)
- [Bumping external tool versions](#bumping-external-tool-versions)
- [Where to get help](#where-to-get-help)

## Code of conduct

All contributors are expected to follow [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). Reports go to the contacts listed there.

## Architecture

The catalog has six layers:

| Layer | Path | Caller secrets | Purpose |
|---|---|---|---|
| composite actions | `.github/actions/<name>/action.yml` | varies | Atomic primitives (input validators, runners) |
| ecosystem workflows | `.github/workflows/<ecosystem>.yml` | none | Read-only checks against caller code |
| node workflows | `.github/workflows/<node>.yml` | none | npm-based quality gates |
| python workflows | `.github/workflows/<python>.yml` | none | uv + ruff + mypy + pytest |
| deploy workflows | `.github/workflows/<deploy>.yml` | OIDC role per GH Environment | Production deploys |
| governance | `governance/` + `scripts/configure-repo-rulesets.sh` | `gh` admin scope | Declarative state + reconciler |

See [`README.md`](README.md) § Architecture for the full picture and [`docs/VERSIONING.md`](docs/VERSIONING.md) for the pin-by-environment rules.

## Branch model

- **Trunk-based, `main`-only.** All PRs target `main` directly.
- Branch names: `<type>/<scope>-<short-desc>` in kebab-case (Conventional Commits scope). Examples: `feat/composite-action-add`, `fix/python-ci-cache-key`, `test/reconciler-bats`.
- Branch is deleted on merge (ruleset policy `delete_branch_on_merge=true`).
- Direct pushes to `main` are blocked for everyone, including org admins. See [Admin bypass](#admin-bypass-rare) for the narrow escape hatch.

## Local setup

### Prerequisites

| Tool | Version | Used for |
|---|---|---|
| `bash` | 4.0+ | all shell scripts |
| `git` | 2.30+ | version control |
| `gh` | 2.40+ | `gh` CLI; required by the reconciler and CI |
| `jq` | 1.6+ | manifest validation, fixture generation |
| `bats` | 1.11.1 | bats tests under `tests/bats/` |
| `pytest` | 9.1.1 | pytest tests under `tests/python/` |
| `python` | 3.12 | runs `scripts/check_lambda_permission_source_arn.py` and the pytest suite |
| `uv` | latest | (optional) caller recipes; not needed to develop this repo |

### One-time install

```bash
# bats 1.11.1
curl -fsSL https://github.com/bats-core/bats-core/archive/refs/tags/v1.11.1.tar.gz \
  | tar -xz -C /tmp
sudo /tmp/bats-core-1.11.1/install.sh /usr/local
bats --version

# pytest 9.1.1
pip install pytest==9.1.1

# jq (Linux)
sudo apt-get install -y jq
# jq (macOS)
brew install jq
# jq (Windows)
choco install jq
```

### Repository checkout

```bash
git clone git@github.com:spark-match/spark-match-01-devops.git
cd spark-match-01-devops
git checkout main
```

## Running tests

The repo ships **75 bats tests + 15 pytest tests = 90 tests total**. The full suite runs in CI on every PR via `.github/workflows/quality.yml`. Run it locally before pushing:

```bash
# All tests (bats + pytest)
bats tests/bats/
python -m pytest tests/python/ -v

# Just one suite
bats tests/bats/reconciler-check.bats
python -m pytest tests/python/test_lambda.py -v -k TestScanTemplate
```

Expected runtime: bats < 1 s, pytest < 0.5 s. CI adds ~25 s per job (bats download + pip install).

### Adding a new test

- **For a new bash primitive** → add `tests/bats/<subject>.bats`. Reuse `tests/bats/helpers/common.bash` for `ACTION_DIR` and stub definitions.
- **For a new bash script** → add `tests/bats/reconciler-<aspect>.bats` and reuse `tests/bats/helpers/reconciler.bash` for the `gh` stub.
- **For a new Python script** → add `tests/python/test_<subject>.py` and reuse `tests/fixtures/<case>/template.yaml` patterns.

CI auto-discovers `tests/bats/*.bats` and `tests/python/test_*.py`. No workflow changes needed.

## Style and conventions

### Shell

- **Every shell script must pass shellcheck** at `severity: warning`. CI runs `ludeeus/action-shellcheck@2.0.0` against `scripts/` and `.github/actions/`. Local:
  ```bash
  # quick install
  sudo apt-get install shellcheck  # or: choco install shellcheck / brew install shellcheck
  shellcheck scripts/*.sh .github/actions/*/action.sh
  ```
- `set -euo pipefail` at the top of every script.
- Use `#!/usr/bin/env bash` shebang (not `/bin/sh`).
- Disable shellcheck inline ONLY with `# shellcheck disable=SC<id>` placed **above** the line, not on the same line. ANTES-de-la-línea is required because some directives (e.g. SC2034) read the directive on the previous line.

### Bash (test)

- bats tests use `@test "..."` blocks.
- `setup()` and `teardown()` run before/after each test.
- `load 'helpers/<name>'` shares helpers.
- `run` merges stdout+stderr into `$output`; use the `json_output` helper in `helpers/reconciler.bash` for JSON assertions.

### Python

- stdlib-only for production scripts (no third-party deps; CI uses Python 3.12).
- Tests use pytest with classes per concern (e.g. `TestScanTemplate`, `TestResolveScanPaths`, `TestCli`).
- Fixtures live under `tests/fixtures/<case>/`.

### YAML / JSON

- `actionlint` must pass against `.github/workflows/*.yml` (severity: error in CI).
- `yamllint` runs with the default `.yamllint.yml` against all non-workflow YAML (severity: warning).
- JSON manifests validate against `governance/repository-governance.schema.json` via `check-jsonschema`.

### Commit messages

Conventional Commits 1.0.0. Required scopes:

| Scope | Used for |
|---|---|
| `composite` | composite actions |
| `ecosystem`, `node`, `python`, `deploy` | reusable workflows by layer |
| `governance` | manifest, schema, reconciler script |
| `docs` | README, docs/, this file |
| `ci` | `.github/workflows/` (this repo's own CI) |
| `quality` | bats/pytest/shellcheck/schema infra |
| `reconciler` | reconciler script tests |
| `scripts` | other operational scripts |

Examples:

```
feat(composite): add regex validator action
fix(deploy): pin terraform to 1.10.x for compatibility
test(reconciler): add bats suite for configure-repo-rulesets.sh
docs(readme): add Quick start and CACHE rate limits
```

## Pull request workflow

1. **Branch from `main`** with a Conventional Commits scope:
   ```bash
   git checkout main
   git pull --ff-only
   git checkout -b feat/<scope>-<short-desc>
   ```

2. **Make your change**. Add tests if you added logic; update docs if you changed user-facing behavior.

3. **Run tests locally** (see [Running tests](#running-tests)).

4. **Lint locally**:
   ```bash
   shellcheck scripts/*.sh .github/actions/*/action.sh
   actionlint .github/workflows/*.yml
   ```

5. **Commit** with a Conventional Commits subject:
   ```bash
   git commit -m "feat(composite): add regex validator action"
   ```

6. **Push and open the PR**:
   ```bash
   $env:GH_TOKEN = $(gh auth token --user ahincho)

   gh pr create \
     --base main \
     --head feat/<scope>-<short-desc> \
     --title "feat(composite): add regex validator action" \
     --body-file C:\Users\Angel\AppData\Local\Temp\opencode\pr-body.md \
     --assignee ahincho \
     --label "enhancement,github-actions"
   ```

   **Mandatory flags**: `--assignee ahincho` and at least one `--label` (per the conventional-commit type). See the opencode `gh-pr-create` skill for the full convention.

7. **Wait for CI** (actionlint + gitleaks + yamllint + quality/bats + quality/pytest + quality/shellcheck + quality/manifest-schema + CodeQL). All checks must be green before merge.

8. **Wait for CODE OWNERS review**. The ruleset requires `require_code_owner_review: true`. Self-approval is impossible — if you are the sole owner, ask another team member.

9. **Merge with admin squash**:
   ```bash
   gh pr merge <num> --squash --admin --delete-branch
   ```

10. **Clean up locally**:
    ```bash
    git checkout main
    git pull --ff-only
    git remote prune origin
    ```

## Admin bypass (rare)

The ruleset blocks direct pushes to `main` for everyone, including org admins, because `bypass_mode: "pull_request"` only covers the PR context. The escape hatch is the **dual-disable + direct push dance**, used for emergency hotfixes and CODE OWNERS migrations:

1. Temporarily flip the ruleset's `bypass_actors[0].bypass_mode` to `"always"`.
2. Temporarily DELETE the legacy branch protection's `enforce_admins` flag.
3. Direct push to `main`.
4. Restore both flags to their canonical state (`bypass_mode: "pull_request"` and `enforce_admins: true`).
5. Verify with `./scripts/configure-repo-rulesets.sh --check`.

The whole window must be **< 5 seconds** in production. Document the dance in `DEVOPS-UPGRADE.md` and never use it for ordinary PR work.

CODE OWNERS review applies even when `bypass_mode: "always"` if the author is itself a CODE OWNER — in that case, push from a non-CODE-OWNER account or temporarily add the path as `* @devops`.

## Adding a recipe

### Reusable workflow

- Place at the top level of `.github/workflows/`. Subfolders break `uses: ./...`.
- Re-declare `permissions:` for whatever the recipe needs (`contents: read`, `id-token: write`, etc.).
- For deploy recipes, declare secrets by explicit name and follow the same-name convention used by existing deploy recipes (`AWS_DEPLOY_ROLE_ARN`, `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`).
- Update `docs/VERSIONING.md` if the recipe introduces a new convention.
- Add bats/pytest tests if you added logic.

### Composite action

- Place at `.github/actions/<name>/action.yml`. One directory per action.
- Add bats tests at `tests/bats/<name>.bats` reusing `tests/bats/helpers/common.bash`.
- If the action accepts an enum / pattern / required input, wire it through `validate-workflow-inputs` as the first step of every workflow that calls it.

## Bumping external tool versions

- Pin `actionlint` to a release tag (never `main`).
- Pin `yamllint` to `1.35.1` unless the team agrees to migrate to the v2 rewrites.
- Use Dependabot (`.github/dependabot.yml`) for routine bumps. Pin by hand when changing the version the recipe defaults to.

## Where to get help

- **Open an issue** at <https://github.com/spark-match/spark-match-01-devops/issues> for bugs, feature requests, or questions about how a recipe works.
- **Cross-reference** the consumer repo's own issue tracker if your problem is in how a caller wires up a recipe.
- **Security issues**: see [`SECURITY.md`](SECURITY.md) — do not open a public issue.

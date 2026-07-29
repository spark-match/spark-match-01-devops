# Spark Match DevOps

Central repository for CI/CD pipelines, GitHub governance, and quality tooling for the `spark-match` organization. This repo is the **single source of truth** for shared automation that consumer repositories call via reusable workflows and composite actions.

## Quick start

Pick the path that matches what you need:

| You want to… | Do this |
|---|---|
| **Lint your SAM templates for missing `Lambda::Permission.SourceArn`** | Call `lambda-permission-source-arn.yml` from your caller workflow (see [Catalog](#catalog)) |
| **Run your Python project's QA pipeline** | Call `python-ci.yml` ([Catalog → python](#python)) |
| **Deploy a SPA / SAM stack / ECR image / Terraform** | Call one of the [deploy recipes](#deploy) with OIDC + a GitHub Environment |
| **Apply the org ruleset to a new repo** | Add an entry to `governance/repository-governance.json`, then `./scripts/configure-repo-rulesets.sh --apply --repos <name>` ([Governance](#governance)) |
| **Add a new reusable workflow** | See [Contributing → adding a recipe](#adding-a-reusable-workflow-or-composite-action) |
| **Run the 139 tests locally before pushing** | See [Testing](#testing) |

## Architecture

The catalog has **six layers**, each defined by what it inspects or mutates:

| Layer | Path | Caller secrets | Purpose |
|---|---|---|---|
| **composite actions** | `.github/actions/<name>/action.yml` | varies | Atomic, single-purpose primitives reusable across many recipes (input validators, runners) |
| **ecosystem workflows** | `.github/workflows/<ecosystem>.yml` | none | Read-only checks against caller code (actionlint, gitleaks, yamllint, terraform-*, cfn-nag, etc.) |
| **node workflows** | `.github/workflows/<node>.yml` | none | npm-based quality gates (eslint, typecheck, test, build) |
| **python workflows** | `.github/workflows/<python>.yml` | none | uv + ruff + mypy + pytest + bandit + pip-audit |
| **deploy workflows** | `.github/workflows/<deploy>.yml` | OIDC role per GH Environment | Production deploys (Angular SPA, SAM, ECR, Terraform) |
| **governance** | `governance/` + `scripts/configure-repo-rulesets.sh` | `gh` admin scope | Declarative state for the org ruleset + idempotent reconciler |

Every recipe (workflow and composite action) accepts an `environment-name` input. It is informational in ecosystem, node, python, and composite layers (used in job name and step logs), and gates the job on a GitHub Environment in deploy recipes (caller must define the environment and put the OIDC role secret there).

### Quality and governance as code

This repo also ships:

- **`governance/repository-governance.json`** — declarative desired state of the org ruleset across all `spark-match/*` repos.
- **`scripts/configure-repo-rulesets.sh`** — idempotent reconciler: reads the manifest, computes drift, applies via `POST` / `PUT`, backs up before any mutation. Supports `--check`, `--apply`, `--dry-run`, `--repos`, `--strict`, `--prune-unexpected`, `--json`.
- **`tests/`** — 124 bats tests + 15 pytest tests, all running on every PR via `.github/workflows/quality.yml`.
- **`.github/dependabot.yml`** — weekly Monday bump PRs for GitHub Actions (5 groups: aws-actions, actions-ecosystem, marocchino, release-tools, third-party-actions). Each PR has `ahincho` as assignee and `@spark-match/devops` as reviewer.
- **`.github/workflows/release-please.yml`** — auto-cuts a "release PR" on every push to main via `googleapis/release-please-action`. Merging the release PR creates the git tag + GitHub Release.

See [Governance](#governance) for the full picture and [Testing](#testing) for how to run the suite locally.

## Repository layout

```
spark-match-01-devops/
├── .github/
│   ├── CODEOWNERS                       Approval policy (@devops + @product-owners, 16 explicit paths)
│   ├── dependabot.yml                   Weekly GitHub Actions bump PRs (Mon 06:00 UTC, 5 groups)
│   │
│   ├── actions/                         ─── composite actions (atomic primitives) ────
│   │   ├── validate-workflow-inputs/        JSON-schema-driven input validation (REQUIRED / ENUM / PATTERN)
│   │   └── run-pytest-with-args/            uv + pytest runner with arg assembly (PYTEST_TARGETS, EXTRA_FLAGS, PYTEST_ARGS)
│   │
│   ├── ISSUE_TEMPLATE/                  form-based issue templates
│   │   ├── config.yml                       issue chooser + sensitive-report warnings
│   │   ├── bug.yml                          bug report
│   │   ├── feature.yml                      feature request
│   │   └── docs.yml                         docs issue
│   │
│   ├── PULL_REQUEST_TEMPLATE.md         auto-applied PR template (11-type conventional-commit checklist)
│   │
│   ├── release-please-config.json       release-please config (simple release-type, CC → section mapping)
│   │
│   └── workflows/
│       ├── ─── this repo's own CI/release ────────────────────────
│       ├── ci.yml                           this repo's own CI (actionlint + gitleaks + yamllint + quality)
│       ├── codeql.yml                       CodeQL on Actions YAML (push + weekly)
│       ├── release-please.yml               release-please automation (cuts release PRs)
│       │
│       │ ─── catalog recipes: composite-action inputs (not for direct use) ──
│       ├── quality.yml                      reusable: shellcheck + manifest schema + bats + pytest
│       │
│       │ ─── catalog: ecosystem (read-only, no caller secrets) ──────────
│       ├── actionlint.yml                   syntax check on Actions workflows
│       ├── gitleaks.yml                     secret scan (needs GITLEAKS_LICENSE)
│       ├── yamllint.yml                     YAML files (uses caller's .yamllint.yml)
│       ├── terraform-fmt.yml                `terraform fmt -check -recursive`
│       ├── terraform-validate.yml           per-module init+validate (no backend)
│       ├── tflint.yml                       recursive tflint
│       ├── checkov.yml                      static analysis on Terraform
│       ├── cfn-nag.yml                      cfn_nag_scan on SAM templates
│       ├── lambda-permission-source-arn.yml SAM guard for Lambda::Permission SourceArn
│       ├── sonar-python.yml                 SonarCloud Python analysis
│       ├── sonar-terraform.yml              SonarCloud Terraform analysis
│       ├── sonar-typescript.yml             SonarCloud TypeScript analysis
│       │
│       │ ─── catalog: node (npm, no caller secrets) ───────────────────────
│       ├── eslint.yml                       `npm run <lint-script>`
│       ├── node-test.yml                    `npm run <test-script>` with cache
│       ├── node-typecheck.yml               `npm run <typecheck-script>` with cache
│       ├── node-build.yml                   `npm run <build-script>` with cache
│       │
│       │ ─── catalog: python (uv, no caller secrets) ─────────────────────
│       ├── python-ci.yml                    uv + ruff + mypy + pytest + bandit + pip-audit
│       │
│       │ ─── catalog: deploy (AWS OIDC, caller-scoped secrets) ──────────
│       ├── angular-spa-deploy.yml           SPA -> S3 + CloudFront invalidation
│       ├── sam-deploy.yml                   sam build + sam deploy
│       ├── container-deploy-ecr.yml         Dockerfile -> ECR (linux/arm64 default)
│       ├── aws-lambda-invoke.yml            generic OIDC Lambda invoke (JSON payload, status check)
│       ├── migrations.yml                   OIDC Lambda migration invoke (typed payload contract)
│       ├── migrations-dry-run.yml           migration dry-run (read-only) variant of migrations.yml
│       ├── seed-users-advisors.yml          seed `advisors` group via OIDC Lambda
│       ├── seed-users-agents.yml            seed `agents` group via OIDC Lambda
│       ├── seed-users-supervisors.yml       seed `supervisors` group via OIDC Lambda
│       ├── terraform-plan.yml               `terraform plan` per env + sticky PR comment
│       ├── terraform-apply.yml              `terraform apply`, optional drift-only mode
│       ├── terraform-destroy.yml            `terraform apply -destroy`, double-gated by
│       │                                   confirm-destroy-token (DESTROY-<ENV>) and
│       │                                   optional GH Environment approval + post-destroy
│       │                                   cleanup job (CLEANUP-<ENV>)
│       │
│       │ ─── catalog: article (LaTeX, kept for 07-article's toolchain) ────
│       ├── latex-build.yml                  compile LaTeX -> PDF artifact
│       └── latex-release.yml                bump patch + GitHub Release
│
├── docs/
│   ├── CACHE.md                            canonical cache-key convention v4 + rate-limit guidance
│   ├── GOVERNANCE-STANDARD.md              org-wide ruleset + CODEOWNERS standard
│   ├── PYTHON-CI.md                        spec for python-ci.yml (19 inputs + design notes)
│   └── VERSIONING.md                       pin-by-environment rules and conventions
│
├── examples/
│   ├── README.md                           index + scope ("when to use" + "out of scope")
│   └── caller-minimal/                     minimal-but-realistic caller workflows
│       ├── README.md                       index + 6 cross-cutting conventions
│       ├── python-ci/                      uses python-ci.yml
│       ├── node-ci/                         uses gitleaks + eslint + node-test + node-build
│       ├── terraform-ci/                    uses terraform-fmt + validate + tflint + plan
│       └── sam-deploy/                      uses cfn-nag + lambda-permission-source-arn + sam-deploy
│
├── governance/
│   ├── repository-governance.json          desired state of org ruleset (schema v2)
│   └── repository-governance.schema.json   Draft 2020-12 schema; validated by quality.yml
│
├── scripts/                                operational scripts (see scripts/README.md)
│   ├── README.md                           catalog of scripts
│   ├── check_lambda_permission_source_arn.py   ⚙️ required by lambda-permission-source-arn.yml
│   ├── configure-merge-methods.sh              bootstrap org-wide merge policy
│   └── configure-repo-rulesets.sh              declarative reconciler for the ruleset
│
├── tests/                                 124 bats + 15 pytest = 139 tests
│   ├── bats/
│   │   ├── helpers/
│   │   │   ├── common.bash                 stubs for uv / pytest + ACTION_DIR
│   │   │   └── reconciler.bash             gh stub dispatching on URL + HTTP method
│   │   ├── composite-validate.bats         24 tests for validate-workflow-inputs
│   │   ├── composite-run-pytest.bats       9 tests for run-pytest-with-args
│   │   ├── merge-methods.bats              11 tests for configure-merge-methods.sh
│   │   ├── reconciler-prereqs.bats         10 tests for arg parsing + manifest + gh auth
│   │   ├── reconciler-payload.bats         9 tests for build_desired_payload jq
│   │   ├── reconciler-check.bats           11 tests for --check mode
│   │   ├── reconciler-apply.bats           16 tests for --apply mode (PUT/POST/backup)
│   │   ├── reconciler-edge-cases.bats      6 tests for team cache + CRLF + --org override
│   │   ├── release-please-config.bats      16 tests for .github/release-please-config.json
│   │   └── cleanup-batch-pr8.bats          12 tests for PR-8 defaults.run.shell + prs:write + env-name
│   ├── python/
│   │   └── test_lambda.py                  15 tests for check_lambda_permission_source_arn.py
│   └── fixtures/                           SAM template fixtures (5 cases)
│       ├── sam-template-valid/
│       ├── sam-template-missing-sourcearn/
│       ├── sam-template-comments-and-edges/
│       ├── sam-template-mixed-resources/
│       └── sam-template-no-permissions/
│
├── .release-please-manifest.json           current package version (release-please tracked)
│
├── .shellcheckrc                          shell=bash, severity=warning
├── .yamllint.yml                           lint config for non-workflow YAML (excludes ISSUE_TEMPLATE)
│
├── LICENSE                                 GPL-3.0-or-later
├── README.md                               this file
├── CHANGELOG.md                            Keep-a-Changelog format; release-please maintained
├── CONTRIBUTING.md                         local setup + workflow + admin bypass dance
├── SECURITY.md                             vulnerability disclosure + 48h/7d/30d/90d SLA
└── CODE_OF_CONDUCT.md                      Contributor Covenant v2.1
```

## Composite actions

Composite actions live under `.github/actions/<name>/`. Each one is an **atomic, single-purpose primitive** that reusable workflows compose. Composite actions are the inner layer; workflows are the public surface that consumer repos call.

### `validate-workflow-inputs`

JSON-Schema-driven validator that gates a workflow step on the validity of its inputs. Fails fast with `::error::` annotations so the workflow exits at the first invalid input rather than producing confusing downstream errors. Used by `quality.yml` to gate every `shellcheck-severity`, `schema-strict`, and similar enum input.

Inputs:

| Input | Type | Required | Notes |
|---|---|---|---|
| `values` | string | yes | JSON object `{ "<input-name>": "<value>" }` of the values to validate. |
| `required` | string | no | JSON array of input names that must be non-empty. Empty array = skip REQUIRED checks. |
| `enums` | string | no | JSON object `{ "<input-name>": ["allowed1", "allowed2"] }`. Empty object = skip ENUM checks. |
| `patterns` | string | no | JSON object `{ "<input-name>": "regex" }`. Uses `grep -E`. Empty object = skip PATTERN checks. |

Errors are collected (not first-fail), then surfaced as a single `::error::` block listing every problem. Exit code contract: `0` on success, `1` on validation failure.

Usage:

```yaml
steps:
  - name: Validate inputs
    uses: spark-match/spark-match-01-devops/.github/actions/validate-workflow-inputs@main
    with:
      values: |
        {"environment-name": "${{ inputs.environment-name }}", "shellcheck-severity": "${{ inputs.shellcheck-severity }}"}
      enums: |
        {"shellcheck-severity": ["warning", "error", "info", "style"]}
```

### `run-pytest-with-args`

Thin wrapper around `uv run pytest` that assembles the CLI from caller-provided env vars. Used by every recipe that runs pytest (currently `quality.yml`'s pytest job, future contributors that need test execution).

Inputs (all environment variables, because composite actions run in the caller's shell):

| Env var | Required | Notes |
|---|---|---|
| `PYTEST_TARGETS` | yes | Space-separated path(s) passed as positional args. |
| `EXTRA_FLAGS` | no | Prepended after `pytest`, before targets (e.g. `--tb=short -v`). |
| `PYTEST_ARGS` | no | Appended after targets (e.g. `--cov=src --cov-report=xml:coverage.xml`). |
| `WORKING_DIRECTORY` | yes | Where `cd` runs before invoking `uv`. |

Behavior: `set -u`, `set -e`, `set -o pipefail`. Missing `PYTEST_TARGETS` or `WORKING_DIRECTORY` aborts with a non-zero exit. The final command shape is:

```
uv pytest ${EXTRA_FLAGS} ${PYTEST_TARGETS} ${PYTEST_ARGS}
```

Usage:

```yaml
steps:
  - name: Run tests
    uses: spark-match/spark-match-01-devops/.github/actions/run-pytest-with-args@main
    env:
      PYTEST_TARGETS: tests
      EXTRA_FLAGS: --tb=short -v
      PYTEST_ARGS: --cov=src
      WORKING_DIRECTORY: ${{ inputs.working-directory }}
```

## Catalog

The recipes live at the top level of `.github/workflows/`. GitHub Actions requires reusable workflows at the top level, so the four workflow layers (ecosystem, node, python, deploy) are encoded by naming and ordering rather than by subdirectory. Composite actions (see above) live under `.github/actions/` instead.

### ecosystem

| Recipe | Purpose | Caller secrets |
|---|---|---|
| `actionlint.yml` | Validate GitHub Actions syntax | — |
| `gitleaks.yml`   | Scan git history for accidentally committed secrets (pinned to `gitleaks/gitleaks-action@v3`) | `GITLEAKS_LICENSE` (required for org-scoped repos under v3) |
| `yamllint.yml`   | Lint non-workflow YAML files (SAM templates, Terraform configs, etc.); pinned to yamllint 1.35.1 | — |
| `terraform-fmt.yml`     | `terraform fmt -check -recursive -diff` on the caller's Terraform tree | — |
| `terraform-validate.yml` | `terraform init -backend=false` + `terraform validate` for every auto-discovered module | — |
| `tflint.yml`            | `tflint --recursive` using caller's `.tflint.hcl` config | — |
| `checkov.yml`           | Static analysis with checkov (pinned 3.2.415), terraform framework, hard-fail | — |
| `cfn-nag.yml`           | `cfn_nag_scan` over `template.yaml` and any `contexts/**/template.yaml`; ruby version pinned, supports AWS SAM guards that cfn-nag 0.8.10 covers natively. The **specific guard for `Lambda::Permission` without `SourceArn`/`SourceAccount`** is the sibling `lambda-permission-source-arn.yml` reusable (cfn-nag 0.8.10 has no rule for this case). | — |
| `lambda-permission-source-arn.yml` | Custom SAM guard that scans `template.yaml` + `contexts/**/template.yaml` and fails when an `AWS::Lambda::Permission` resource lacks `SourceArn:` or `SourceAccount:`. The scan logic lives at `scripts/check_lambda_permission_source_arn.py` (stdlib-only Python, regex-based, comment-aware). Required because cfn-nag 0.8.10's Lambda rules only check `W24` (action) and `F45` (EventSourceToken); neither validates `SourceArn` presence, so the cross-API confusion vulnerability that AWS API Gateway exposes remains uncaught without this check. | — |

#### `actionlint.yml`

Validates `.github/workflows/*.yml` in the caller. Downloads the actionlint binary pinned to `v1.7.7` (avoid tracking `main` for supply-chain safety).

Inputs:

| Input        | Type   | Default | Notes                                                |
|--------------|--------|---------|------------------------------------------------------|
| environment-name | string | `dev` | Informational only; used in the job name and logs. |

Usage:

```yaml
jobs:
  actionlint:
    uses: spark-match/spark-match-01-devops/.github/workflows/actionlint.yml@main
    with:
      environment-name: ci
```

#### `gitleaks.yml`

Runs secret scanning against the full git history. Pinned to `gitleaks-action@v3`; for org-scoped repos callers MUST forward the `GITLEAKS_LICENSE` secret (free at gitleaks.io) because GitHub drops `secrets: inherit` across owner boundaries. The org-level Dependabot secret bucket holds `GITLEAKS_LICENSE` (visibility: all-repos) so Dependabot-triggered runs see it without per-repo setup.

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | `dev` | Informational only. |

Usage:

```yaml
jobs:
  gitleaks:
    uses: spark-match/spark-match-01-devops/.github/workflows/gitleaks.yml@main
    with:
      environment-name: ci
```

#### `yamllint.yml`

Validates YAML files in the caller repo. yamllint auto-discovers `.yamllint.yml`, so config (ignores, rule relaxations) is the caller's responsibility. Typical ignore set:

```yaml
ignore: |
  .git/
  node_modules/
  coverage/
  dist/
  .terraform/
  .github/workflows/   # validated by actionlint, not yamllint
```

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | `dev` | Informational only. |

Pinned to yamllint `1.35.1` (last v1 release before the v2 rewrite).

Usage:

```yaml
jobs:
  yamllint:
    uses: spark-match/spark-match-01-devops/.github/workflows/yamllint.yml@main
    with:
      environment-name: ci
```

#### `terraform-fmt.yml`

Runs `terraform fmt -check -recursive -diff` on the caller's Terraform tree. Recursion covers submodules automatically, so monorepos (e.g. `live/dev/` + `modules/*`) get the whole tree checked with one call. No AWS needed.

Inputs:

| Input        | Type   | Default | Notes                                                |
|--------------|--------|---------|------------------------------------------------------|
| environment-name | string | `dev` | Informational only; used in the job name and logs. |
| terraform-version | string | `1.10.0` | X.Y.Z format. Defaults match the `terraform-plan.yml` default. |
| working-directory | string | `.` | Where `terraform fmt -recursive` starts. |

Usage:

```yaml
jobs:
  terraform-fmt:
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-fmt.yml@main
    with:
      environment-name: dev
      terraform-version: 1.15.7
```

#### `terraform-validate.yml`

Discovers every Terraform module in the caller (by `.tf` files at any directory level, excluding `.terraform/` and `.git/`) and runs `terraform init -backend=false` + `terraform validate` for each. Because `-backend=false` skips the S3/DynamoDB backend, no AWS credentials are needed. Providers come from the registry, pinned by the committed `.terraform.lock.hcl`.

Inputs:

| Input        | Type   | Default | Notes                                                |
|--------------|--------|---------|------------------------------------------------------|
| environment-name | string | `dev` | Informational only. |
| terraform-version | string | `1.10.0` | X.Y.Z format. |
| working-directory | string | `.` | Discovery starts here; walks recursively. |

Usage:

```yaml
jobs:
  terraform-validate:
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-validate.yml@main
    with:
      environment-name: dev
      terraform-version: 1.15.7
```

#### `tflint.yml`

Runs `tflint --recursive` against the caller's Terraform code. Caller must provide a `.tflint.hcl` at the repo root — TFLint reads it per-subdirectory and follows the plugin set declared there.

Pins:

- `terraform-linters/setup-tflint@v6` (bumped from v4 in an `orion-infrastructure` PR)
- `tflint_version: latest` (caller can pin via `.tflint.hcl` config)

Inputs:

| Input        | Type   | Default | Notes                                                |
|--------------|--------|---------|------------------------------------------------------|
| environment-name | string | `dev` | Informational only. |
| terraform-version | string | `1.10.0` | Required by `setup-tflint` for plugin discovery. |
| working-directory | string | `.` | Where `tflint --recursive` runs. |

Usage:

```yaml
jobs:
  tflint:
    uses: spark-match/spark-match-01-devops/.github/workflows/tflint.yml@main
    with:
      environment-name: dev
```

#### `checkov.yml`

Runs `checkov --directory . --framework terraform --compact` against the caller's Terraform code. Hard-fail mode: callers justify each skip inline with `# checkov:skip=CKV_AWS_XX:reason` next to the offending resource. Pinned to checkov `3.2.415` for reproducible output (discipline established in `orion-infrastructure`).

Discipline:

- Findings must be fixed in the resource, OR
- Findings must be skipped inline with a written justification.

Inputs:

| Input        | Type   | Default | Notes                                                |
|--------------|--------|---------|------------------------------------------------------|
| environment-name | string | `dev` | Informational only. |
| checkov-version | string | `3.2.415` | X.Y.Z format. Pin for reproducible lint output. |
| working-directory | string | `.` | Checkov scan root. |

Usage:

```yaml
jobs:
  checkov:
    uses: spark-match/spark-match-01-devops/.github/workflows/checkov.yml@main
    with:
      environment-name: dev
```

#### `cfn-nag.yml`

Runs [`cfn_nag_scan`](https://github.com/stelligent/cfn_nag) over `template.yaml` and every `contexts/**/template.yaml` in the caller. Reads comments to suppress findings inline (`# cfn_nag_suppress: RULE_ID reason`). Ruby version pinned via `ruby/setup-ruby@v1`; cfn-nag gem version pinned via input.

Inputs:

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | `dev` | Informational only. |
| `cfn-nag-version` | string | `0.8.10` | Pinned for reproducible output. |
| `ruby-version` | string | `3.3` | Pinned for reproducible output. |
| `scan-paths` | string | `template.yaml contexts/` | Space-separated. |
| `output-format` | string | (none) | Optional; pass `json` for machine-readable output. |

Usage:

```yaml
jobs:
  cfn-nag:
    uses: spark-match/spark-match-01-devops/.github/workflows/cfn-nag.yml@main
    with:
      environment-name: dev
```

#### `lambda-permission-source-arn.yml`

Companion to `cfn-nag.yml`. Runs the script at `scripts/check_lambda_permission_source_arn.py` against the caller's SAM templates. Fails CI when an `AWS::Lambda::Permission` resource declares neither `SourceArn:` nor `SourceAccount:`.

Why this exists: cfn-nag 0.8.10's Lambda rules (W24 = action is `InvokeFunction`, F45 = no plaintext `EventSourceToken`) do NOT check for a missing `SourceArn`. Without it, AWS API Gateway can invoke the Lambda function from any other API in the same account (cross-API confusion). The defense-in-depth is the Lambda resource policy itself, which REQUIRES `SourceArn` to scope invocation. cfn-nag ships no rule for this case, hence this guard.

Inputs:

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | `dev` | Informational only. |
| `python-version` | string | `3.12` | The runner python used to invoke the script. |
| `scan-paths` | string | `template.yaml contexts/` | Space-separated. |

Usage:

```yaml
jobs:
  lambda-permission-source-arn:
    uses: spark-match/spark-match-01-devops/.github/workflows/lambda-permission-source-arn.yml@main
    with:
      environment-name: dev
```

#### `sonar-python.yml`

SonarCloud analysis for Python projects. Pinned to a recent SonarScanner CLI; runs `sonar-scanner` with the caller's `sonar-project.properties` values as inputs. Used by `orion-backend` and `orion-identity`.

Inputs (highlights):

| Input | Type | Notes |
|---|---|---|
| `project-key` | string (required) | SonarCloud project key. |
| `organization` | string (required) | SonarCloud organization key. |
| `sources` | string (required) | Comma-separated source paths (relative to `working-directory`). |
| `tests` | string | Comma-separated test paths; empty disables test analysis. |
| `coverage` | string | Path to coverage report (e.g. `coverage.xml`); empty skips coverage. |
| `working-directory` | string | `.` |
| `sonar-host-url` | string | `https://sonarcloud.io` |

Required secrets: `SONAR_TOKEN` (same-name convention). Caller must set it in the GitHub Environment.

#### `sonar-terraform.yml`

SonarCloud analysis for Terraform. Designed for projects where Terraform is the primary language (no Python/JS). Companion to `sonar-python.yml`.

Same input shape as `sonar-python.yml` plus `exclude-patterns` (comma-separated globs to exclude from sources).

#### `sonar-typescript.yml`

SonarCloud analysis for TypeScript. Used by `orion-frontend`. Adds the `tsconfig.json` path as input so Sonar can resolve TypeScript types during analysis.

Same input shape as `sonar-python.yml` plus `tsconfig-path` (default `tsconfig.json`).

### node

#### `eslint.yml`

Runs `npm run <lint-script>` for Node workspaces and caches `~/.npm` keyed on `os-node<node-version>-eslint<eslint-version>-package-lock.json`. Includes `eslint-version` so callers can roll forward to a new ESLint major without forking the recipe (cache key changes so no stale cache).

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | `dev` | Informational only. |
| node-version | string | `24`    | Passed to `actions/setup-node`. |
| eslint-version | string | `10` | Major only (used as cache key segment). |
| lint-script  | string | `lint` | The npm script name in `package.json`. |
| working-directory | string | `.` | Where `npm ci` runs (where `package.json` lives). |

Usage:

```yaml
jobs:
  eslint:
    uses: spark-match/spark-match-01-devops/.github/workflows/eslint.yml@main
    with:
      environment-name: ci
      eslint-version: 10
      # lint-script defaults to "lint"
```

#### `node-test.yml`

Runs `npm run <test-script>` against a Node project's `tests/` directory with the canonical cache key (`<os>-node<nodeVersion>-<pkgManager>-<env>-<H>` per [`docs/CACHE.md`](docs/CACHE.md)). Supports an optional `pre-test-script` for callers that need a build/precompile step before tests (e.g. Angular's prebuild hook).

Inputs:

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | `dev` | Informational only. |
| `node-version` | string | `24` | Passed to `actions/setup-node@v7`. |
| `pkg-manager` | string | `npm` | `npm` \| `pnpm` \| `yarn` \| `bun`. |
| `lockfile-name` | string | `package-lock.json` | Becomes the cache key's `<H>` segment. |
| `pre-test-script` | string | `''` | Optional npm script to run before tests (Angular prebuild hook, etc.). Empty = skip. |
| `test-script` | string | `test` | The npm script name in `package.json`. |
| `working-directory` | string | `.` | Where `npm ci` runs (where `package.json` lives). |

Usage:

```yaml
jobs:
  node-test:
    uses: spark-match/spark-match-01-devops/.github/workflows/node-test.yml@main
    with:
      environment-name: ci
      test-script: test
      pre-test-script: prebuild
```

#### `node-typecheck.yml`

Runs `npm run <typecheck-script>` for Node projects (Angular, Vite, Next.js, plain TS). Uses the canonical cache key v4 (`<os>-node<nodeVersion>-<pkgmanager>-<env>-<H>` per [`docs/CACHE.md`](docs/CACHE.md)). Intended for projects that want strict type checking in CI but don't bundle the typecheck inside another job (Angular: `tsc --noEmit -p tsconfig.app.json`).

Inputs:

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | `dev` | Informational only. |
| `node-version` | string | `24` | Passed to `actions/setup-node@v7`. |
| `pkg-manager` | string | `npm` | `npm` \| `pnpm` \| `yarn` \| `bun`. |
| `lockfile-name` | string | `package-lock.json` | Becomes the cache key's `<H>` segment. |
| `typecheck-script` | string | `typecheck` | The npm script name in `package.json`. |
| `working-directory` | string | `.` | Where `npm ci` runs (where `package.json` lives). |

Usage:

```yaml
jobs:
  typecheck:
    uses: spark-match/spark-match-01-devops/.github/workflows/node-typecheck.yml@main
    with:
      environment-name: ci
      # typecheck-script defaults to "typecheck"
```

#### `node-build.yml`

Runs `npm run <build-script>` for Node projects (Angular: `ng build`; Vite/React: `vite build`; Next.js: `next build`). Uses the canonical cache key v4. Supports an optional `pre-build-script` for monorepos or frameworks that need a precompile step (Angular prebuild hook, backend shared workspace, etc.).

Inputs:

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | `dev` | Informational only. |
| `node-version` | string | `24` | Passed to `actions/setup-node@v7`. |
| `pkg-manager` | string | `npm` | `npm` \| `pnpm` \| `yarn` \| `bun`. |
| `lockfile-name` | string | `package-lock.json` | Becomes the cache key's `<H>` segment. |
| `build-script` | string | `build` | The npm script name in `package.json`. For Angular production builds, callers typically pass `'build --configuration=production'` (npm forwards args after `--`). |
| `pre-build-script` | string | `''` | Optional npm script to run before the build (Angular prebuild hook, etc.). Empty = skip. |
| `working-directory` | string | `.` | Where `npm ci` runs (where `package.json` lives). |

Usage:

```yaml
jobs:
  build:
    needs: [eslint, typecheck, test]
    uses: spark-match/spark-match-01-devops/.github/workflows/node-build.yml@main
    with:
      environment-name: ci
      # build-script defaults to "build"
      # pre-build-script optional (Angular: 'prebuild')
```

### python

#### `python-ci.yml`

Runs a Python project's QA pipeline using `uv` for dependency management, then `ruff` + `mypy` + `pytest` for static analysis + tests, plus optional `bandit` (security lint) and `pip-audit` (dependency vulnerability scan). Designed for projects that pin Python in `.python-version` and lock via `uv.lock`. The recipe is GENERIC: it does not assume a specific project layout beyond `pyproject.toml` + `uv.lock` in `working-directory`.

Each step is gated by an entry in the CSV `commands` input, so callers can opt into any subset (e.g. skip `mypy` on a legacy codebase, or skip `coverage:upload` if the project doesn't generate coverage). Defaults run the full QA set + upload coverage as an artifact.

The recipe has **19 inputs**; the table below covers the inputs most callers actually override. For the full input catalog (sync flags, cache key, timeout, etc.) see [`docs/PYTHON-CI.md`](docs/PYTHON-CI.md) § 3.

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | — (required) | Used as job name + optional GH Environment gate. |
| working-directory | string | `.` | Where `pyproject.toml` + `uv.lock` live. |
| runs-on | string | `ubuntu-latest` | Caller can pin to a larger runner (`ubuntu-4cpu-8gb-ephemeral`) for heavy matrix. |
| commands | string | `lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest,coverage:upload` | CSV; valid steps: `lint:ruff-format`, `lint:ruff-check`, `lint:bandit`, `lock:check`, `typecheck:mypy`, `test:pytest`, `coverage:upload`, `security:pip-audit`, `none` (manual-mode only). |
| sync-mode | string | `full` | Dependency installation scope. One of: `full` (all groups; default), `runtime-only` (skip `--group` to install only the `[project]` deps), `lint-only` (install only the `lint` group; useful for fast lint loops without runtime deps). See [`docs/PYTHON-CI.md`](docs/PYTHON-CI.md) § 3.4 (Sprint C). |
| dependency-groups | string | `dev` | Passed to `uv sync --group` (space-separated, only when `sync-mode=full`). Use `dev bedrock` to also enable a `bedrock` group. |
| lock-check | bool | `false` | When `true`, verifies `uv.lock` is coherent with `pyproject.toml` before running tools. |
| frozen | bool | `false` | When `true`, prevents `uv sync` from regenerating `uv.lock` (caller is expected to have already promoted the lockfile). |
| ruff-targets | string | `src tests` | CSV of paths for `ruff format/check`. |
| mypy-targets | string | `src` | CSV of paths for `mypy`. |
| pytest-targets | string | `tests` | Path for `pytest`. |
| pytest-args | string | `''` | Extra args appended to `pytest`. |
| coverage-output | string | `coverage.xml` | Artifact path uploaded (when `coverage:upload` is in `commands`). |
| coverage-threshold | number | `''` | Min coverage % to gate on; CI fails below this threshold. Empty = no threshold. |
| permissions-write | bool | `false` | When `true`, the job grants `pull-requests: write` so the sticky PR coverage comment step can post. The default `false` is strictly read-only. |
| cache-suffix | string | `''` | Extra segment appended to the `actions/cache` key; useful when callers need to bust the cache on a parameter change. |
| setup-uv-version | string | `latest` | uv version pinned via `astral-sh/setup-uv@v7`. |
| timeout-minutes | number | `20` | Job-level timeout. |
| fail-fast | bool | `false` | Set `true` on the matrix to abort on first failure. |

Required secrets: none (ecosystem-style, no AWS). The sticky coverage comment step requires `permissions: pull-requests: write` on the caller if `permissions-write` is not passed.

Usage (typical orion-cognitive-agent layout — both `dev` and `bedrock` groups, with security scan):

```yaml
jobs:
  python-ci:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@main
    with:
      environment-name: ci
      working-directory: '.'
      dependency-groups: 'dev bedrock'
      commands: lint:ruff-format,lint:ruff-check,lint:bandit,lock:check,typecheck:mypy,test:pytest,coverage:upload,security:pip-audit
```

Usage (single-version matrix, fast lint-only loop):

```yaml
jobs:
  python-ci:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@main
    with:
      environment-name: ci
      sync-mode: lint-only
      commands: lint:ruff-format,lint:ruff-check
      dependency-groups: lint
```

For multi-version matrix (when the cross-owner GHA bug is resolved upstream), pass `python-versions: '"3.11","3.12"'`. Today the recipe hardcodes `python-version: ["3.12"]` on the matrix; see [`docs/PYTHON-CI.md`](docs/PYTHON-CI.md) § 8.1.

### deploy

#### `angular-spa-deploy.yml`

Builds an Angular SPA via `npm ci` + `npm run build`, syncs the resulting bundle to S3 with `--delete`, and triggers a CloudFront invalidation. Designed for SPAs (Angular / React / Vue) hosted on S3 + CloudFront with OAC. Injects `API_URL` as a build-time env var so the SPA can target a backend per environment.

Inputs:

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | — (required) | Becomes the GH Environment gate. Caller must define the environment and hold the role secret there. |
| `aws-region` | string | `us-east-1` | Region of the S3 bucket and CloudFront distribution. |
| `s3-bucket` | string | — (required) | SPA bucket name (e.g. `orion-frontend-dev`). |
| `cloudfront-distribution-id` | string | — (required) | CloudFront distribution ID for invalidation. |
| `cloudfront-invalidation-paths` | string | `/*` | Paths to invalidate. |
| `node-version` | string | `24` | Node version for build. |
| `build-script` | string | `build` | npm script that builds the SPA. |
| `artifact-path` | string | `dist/orion-frontend/browser` | Path to the built bundle. |
| `api-url` | string | `''` | Build-time env var `API_URL` for the SPA. |
| `sync-extra-args` | string | `''` | Extra flags for `aws s3 sync`. |

Required secrets (caller-side, scoped to the GitHub Environment):

- `AWS_DEPLOY_ROLE_ARN` — IAM role with trust policy for `token.actions.githubusercontent.com`, scoped to the SPA bucket (`s3:GetObject|PutObject|DeleteObject|ListBucket`) and the SPA distribution (`cloudfront:CreateInvalidation`). The `iam-angular-spa-deploy-dev` Terraform module in `orion-infrastructure` creates exactly this shape.

Usage:

```yaml
jobs:
  deploy-dev:
    uses: spark-match/spark-match-01-devops/.github/workflows/angular-spa-deploy.yml@main
    with:
      environment-name: dev
      aws-region: us-east-1
      s3-bucket: orion-frontend-dev
      cloudfront-distribution-id: E1ABC2DEF3GHIJ
      api-url: https://api.orion.dev
    secrets:
      AWS_DEPLOY_ROLE_ARN: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
```

#### `sam-deploy.yml`

Builds and deploys an AWS SAM application via OIDC. Handles checkout, node setup, npm cache, OIDC credentials, `npm ci`, the Lambda Layers build script, SAM CLI install, `sam validate --lint`, `sam build --use-container`, and `sam deploy --config-env <env>` with idempotent flags (`--no-confirm-changeset`, `--no-fail-on-empty-changeset`). The caller must already have `samconfig.toml` with sections `[default]`, `[prod]`, etc., and a Layers build script in `package.json`.

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | — (required) | Becomes the GitHub Environment gate. Caller must define the environment and hold the role secret there. Defaults `sam-config-env` to this value when not provided. |
| aws-region   | string | `us-east-1` | Should match `[<env>].region` in `samconfig.toml`. |
| stack-name   | string | `''` | CloudFormation stack name. Empty = use `samconfig.toml`. |
| sam-template | string | `template.yaml` | Path to the SAM template, relative to repo root. |
| sam-config-env | string | = environment-name | The `[<section>]` name in `samconfig.toml`. |
| s3-bucket    | string | `''` | Artifacts bucket. Empty = use `samconfig.toml` or auto-managed. |
| parameter-overrides-json | string | `{}` | Valid JSON object merged on top of `samconfig.toml` overrides. |
| node-version | string | `24` | Used by the build container for `npm ci` and Layers build. |
| sam-cli-version | string | `1.151.0` | Pinned for reproducible deploys. |
| pre-build-script | string | `build:shared` | npm script to run before Layers build (e.g. compile the shared workspace). Empty = skip. |
| build-layers-script | string | `layer:build:all` | npm script that builds Lambda Layers. Empty = no layers. |

Required secrets (caller-side, scoped to the GitHub Environment):

- `AWS_DEPLOY_ROLE_ARN` — IAM role with trust policy for `token.actions.githubusercontent.com` and permissions for CloudFormation, IAM, S3, SSM, and Lambda publish.

Usage:

```yaml
jobs:
  deploy-dev:
    uses: spark-match/spark-match-01-devops/.github/workflows/sam-deploy.yml@main
    with:
      environment-name: dev
      aws-region: us-east-1
      stack-name: orion-backend-dev
      sam-config-env: default
      s3-bucket: orion-sam-artifacts-dev
    secrets:
      AWS_DEPLOY_ROLE_ARN: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
```

The caller workflow must also declare `id-token: write` at the workflow or job level (GitHub mints the OIDC JWT from the caller's permissions context).

#### `container-deploy-ecr.yml`

Builds a Dockerfile via `docker buildx` and pushes the resulting image to an existing Amazon ECR repository. The caller is responsible for provisioning the ECR repository via Terraform (no `ecr create-repository` here) and for holding the deploy-role OIDC trust policy. Designed for `orion-cognitive-agent` today, but reusable for any project that pushes a container image to a pre-existing ECR repository. Default platform is `linux/arm64` (Bedrock AgentCore contract); override with `amd64` if needed.

The recipe does NOT create the ECR repository. It expects the caller to pass a `ecr-repository` name that already exists with proper ECR pull/push policies.

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | — (required) | GH Environment gate + job name + concurrency key. |
| aws-region | string | `us-east-1` | ECR repository region. |
| ecr-repository | string | — (required) | ECR repository name (no registry prefix). Must match `^[a-z0-9][a-z0-9_-]{0,254}$`. |
| dockerfile-path | string | `Dockerfile` | Path to the Dockerfile relative to repo root. |
| context-path | string | `.` | Build context relative to repo root. |
| platforms | string | `linux/arm64` | Comma-separated `docker buildx` platforms. Use `linux/amd64` for x86_64 deploys. |
| image-tags-input | string | `latest,__GITHUB_SHA_SHORT__` | Comma-separated tag list; `__GITHUB_SHA_SHORT__` expands to the first 7 chars of `${{ github.sha }}`. |
| cache-scope | string | `container-dev` | GHA cache key segment (`cache-from type=gha,scope=<scope>`). Lets multiple recipes coexist on the same runner without cross-contamination. |
| provenance | string | `false` | `provenance:` flag for `docker build-push-action`. |
| sbom | string | `false` | `sbom:` flag for `docker build-push-action`. |
| extra-buildx-args | string | `''` | Raw extra args passed through. Rarely needed. |

Required secrets (caller-side, scoped to the GitHub Environment):

- `AWS_DEPLOY_ROLE_ARN` — IAM role with trust policy for `token.actions.githubusercontent.com`, `sub` restricted to `repo:<owner>/<caller>:ref:refs/heads/main`, and permissions for `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, and `sts:GetCallerIdentity`. The `module.iam_orion_agent_core_deploy` Terraform module in `orion-infrastructure` produces exactly this shape.

Usage (typical orion-cognitive-agent):

```yaml
jobs:
  deploy-dev:
    uses: spark-match/spark-match-01-devops/.github/workflows/container-deploy-ecr.yml@main
    with:
      environment-name: dev
      ecr-repository: orion-agent-core-dev
    secrets:
      AWS_DEPLOY_ROLE_ARN: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
```

The caller workflow must also declare `id-token: write` at the workflow or job level (GitHub mints the OIDC JWT from the caller's permissions context).

#### `terraform-plan.yml`

Runs `terraform plan` per environment. Posts a sticky comment on the PR with the plan summary, uploads the plan binary as an artifact, and respects a per-environment backend config. Designed to be called from a matrix `[dev, staging, prod, ...]` in the caller.

Key inputs (full list in the file header):

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment  | string | `''` (basename of `working-directory`) | Used for artifact naming and sticky-comment header. |
| working-directory | string | `.` | Where `terraform init` runs. |
| aws-region   | string | `us-east-1` | |
| plan-role-arn-secret | string | `AWS_PLAN_ROLE_ARN` | Name of the GitHub Secret holding the plan-role ARN. Same-name convention lets cross-owner callers work. |
| terraform-version | string | `1.10.0` | |
| backend-bucket / backend-key / tfvars-file / var-files / target / extra-args | string | various | Standard passthrough. |
| comment-on-pr | bool | `true` | |
| retention-days | number | `7` | 1-90 (GitHub Actions limits). |

Required secrets: `AWS_PLAN_ROLE_ARN` (passed explicitly; cross-owner inheritance blocked by GitHub).

#### `terraform-apply.yml`

Runs `terraform apply` per environment with an optional GitHub Environment approval gate (`gh-environment` input or fallback to `environment`). Supports `drift-only` mode for scheduled drift detection without applying.

Key inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment | string | `''` (basename of `working-directory`) | Display + concurrency. |
| working-directory | string | `.` | |
| aws-region   | string | `us-east-1` | |
| apply-role-arn-secret | string | `AWS_APPLY_ROLE_ARN` | |
| terraform-version | string | `1.10.0` | |
| backend-bucket / backend-key / tfvars-file / var-files / target / extra-args | string | various | Standard passthrough. |
| gh-environment | string | = environment | Approval gate name. Falls back to `environment`. |
| auto-approve | bool | `false` | Skip approval (only for non-prod envs with empty reviewers list). |
| drift-only | bool | `false` | Plan only, post summary, do not apply. Useful for scheduled drift detection. |

Required secrets: `AWS_APPLY_ROLE_ARN` (passed explicitly).

#### `terraform-destroy.yml`

Runs `terraform plan -destroy` then `terraform apply -destroy` per environment. Complementary to `terraform-apply.yml` — when you need to tear down an environment instead of build it up. Two independent gates prevent fat-finger mistakes:

1. **`confirm-destroy-token` input** — the job aborts unless this input equals exactly `DESTROY-<ENV>` (case-sensitive, all caps). The caller is responsible for collecting this from a human before invoking (typically via `workflow_dispatch` with the `confirm_destroy` field). Failure logs the expected token and the length of what was received (never the value).
2. **`gh-environment` input** — optional approval gate via GitHub Environment. Falls back to `environment`. For non-prod envs that intentionally have no reviewers, set `auto-approve: true`.

The recipe also uploads the **current state as an artifact** before the apply step, so operators can recover from a bad destroy by re-applying against the backup. `dry-run: true` mode plans only without applying (preview what would be removed).

Concurrency: `cancel-in-progress: false` — destroys in flight must complete or be rolled back by hand. Re-running requires the lock to release naturally.

Key inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment | string | `''` (basename of `working-directory`) | Display + concurrency. Also forms the suffix of the required confirm token (`DESTROY-<ENV>`). |
| working-directory | string | `.` | |
| aws-region | string | `us-east-1` | |
| apply-role-arn-secret | string | `AWS_APPLY_ROLE_ARN` | The role needs admin-equivalent rights; destroy recreates resources. |
| terraform-version | string | `1.10.0` | |
| backend-bucket / backend-key / tfvars-file / var-files / target / extra-args | string | various | Standard passthrough. |
| confirm-destroy-token | string | **REQUIRED** | Must equal `DESTROY-<ENV>` exactly. The caller collects this from a human (typically via `workflow_dispatch`). |
| gh-environment | string | = environment | Approval gate name. |
| auto-approve | bool | `false` | Skip approval (only for non-prod envs with empty reviewers). |
| dry-run | bool | `false` | Plan only — no resources are destroyed. Useful for previewing what would be removed. |
| retention-days | number | `14` | 1-90 (GitHub Actions limits); for the plan artifact and the pre-destroy state backup. |
| project-name | string | `''` (auto-derive from `backend-bucket`) | Used as the filter prefix for log groups (`/aws/lambda/<project>-*`, etc.), SSM parameters (`/<project>/*`), S3 buckets (`<project>-sam-artifacts-*`), and CloudFormation stacks (`<project>-*`). Auto-derived from `backend-bucket` when empty using the pattern `<project>-tfstate-<env>` (so `orion-tfstate-dev` produces `orion`). Pass explicitly only if your bucket name does not follow the convention. |
| enable-cleanup | bool | `false` | Run the post-destroy cleanup job. Only executes if destroy was successful. |
| cleanup-token | string | `''` | Required when `enable-cleanup=true`. Must equal `CLEANUP-<ENV>` (case-sensitive). Separate gate so cleanup cannot run accidentally on a destroy-only invocation. |

Required secrets: `AWS_APPLY_ROLE_ARN` (passed explicitly).

##### Post-destroy cleanup (optional job)

When `enable-cleanup=true` and `cleanup-token` equals `CLEANUP-<ENV>`, the reusable runs a second job (`cleanup-residuals`) after `destroy` succeeds. It cleans the categories that Terraform + CloudFormation do not touch on their own:

| Category | Pattern swept | Source of the leftover |
|---|---|---|
| CloudWatch log groups | `/aws/lambda/<project>-*`, `/aws/api-gateway/<project>-*`, `/aws/bedrock-agentcore/runtimes/<project>_*`, `/aws/rds/instance/<project>-*`, `/aws/vpc/<project>-*` | Auto-created by AWS services the first time they log. Not in Terraform state. |
| SSM parameters | `/<project>/*` | Often created by smoke-test scripts or hand-written deploys outside Terraform. |
| S3 buckets | `<project>-*-sam-artifacts`, `<project>-*-artifacts`, `<project>-*-sam-deploy` (excluding the `backend-bucket`) | Created by `sam deploy` or other tools. Not in Terraform state. |
| CloudFormation stacks | `<project>-*` in any active state (excludes `DELETE_COMPLETE` history) | Stacks deployed via SAM or other IaC tools that the destroy recipe does not touch. |

Behavior:

- Only runs if `needs.destroy.result == 'success'`. A failed destroy blocks the cleanup — operators can re-run destroy first, then enable cleanup.
- Idempotent: re-running on already-clean state is a no-op (already-deleted resources are skipped).
- `dry-run: true` propagates: the cleanup job lists matches and writes them to the step summary without deleting.
- CloudFormation `delete-stack` is async — the stack itself transitions to `DELETE_COMPLETE` minutes later. Re-running the workflow (with the same token) confirms.
- The `backend-bucket` is excluded from S3 sweep by name match (it's the Terraform state bucket, owned by a different destroy step).
- IAM users (e.g. `orion-admin`) and GitHub-side resources (Secrets, Variables, Environments) are NOT touched.

Caller-side example:

```yaml
jobs:
  destroy:
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-destroy.yml@main
    with:
      # ...destroy inputs as usual...
      enable-cleanup: true
      cleanup-token: ${{ inputs.cleanup_token }}
      # project-name omitted — auto-derived from backend-bucket via the
      # `<project>-tfstate-<env>` convention. Pass explicitly only if your
      # bucket name does not match that pattern.
```

The caller's `workflow_dispatch` typically collects `cleanup_token` as a separate input (`CLEANUP-DEV` for `dev`, `CLEANUP-PROD` for `prod`), paralleling `confirm_destroy`.

Workflow-level outputs added to expose cleanup state to chained jobs:

- `cleanup-success` — `true` only if every cleanup category succeeded.
- `cleanup-deleted-count` — total resources deleted across all categories.

A sticky PR comment (`terraform-cleanup-residuals-failed-<env>` header) is posted when any cleanup step fails, with a pointer to the per-step logs and a note that re-running is idempotent.

**Chicken-and-egg note**: if the state bucket (`backend-bucket`) is itself going to be destroyed as part of the run, you must migrate state to a local backend BEFORE invoking this recipe. The recipe does not rewrite `versions.tf` from inside the workflow (the file mutation is too fragile across callers). Pattern at the call site:

```bash
# One-off preflight (run locally or as a separate workflow step)
cd live/dev
cat > backend-override.hcl <<EOF
path        = "tfstate.tfstate.local"
lock_method = "local"
EOF
terraform init -migrate-state -force-copy -input=false \
    -backend-config=backend-override.hcl

# Then invoke the reusable workflow with backend-bucket = '' (empty) — the
# reusable detects the local backend and skips the -backend-config step.
```

After destroy you can `rm backend-override.hcl tfstate.tfstate.local*` and run the normal init to re-attach S3 if you only needed a partial destroy.

#### `aws-lambda-invoke.yml`

Generic OIDC Lambda invoke + status check. Wraps `aws lambda invoke --cli-read-timeout`, parses the `StatusCode` (HTTP-equivalent) and `FunctionError` fields, and fails the workflow on any non-200 or thrown error. The Lambda contract is documented inline (JSON payload, async invocation vs request-response, FunctionError semantics).

Inputs (highlights):

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | `dev` | Becomes the GH Environment gate. |
| `aws-region` | string | `us-east-1` | Region of the target Lambda. |
| `function-name` | string | — (required) | Lambda name or ARN. |
| `payload` | string | `{}` | JSON payload string. |
| `invocation-type` | string | `RequestResponse` | One of `RequestResponse` / `Event` / `DryRun`. |
| `qualifier` | string | (empty) | Lambda version or alias; empty = `$LATEST`. |
| `working-directory` | string | `.` | Where the payload file (if any) lives. |

Required secrets: `AWS_DEPLOY_ROLE_ARN` (same-name convention). Caller must set it in the GH Environment.

#### `migrations.yml` + `migrations-dry-run.yml`

OIDC Lambda invoke specialized for the `orion-identity-migrate-<env>` family of migration Lambdas. `migrations.yml` invokes with `InvocationType=RequestResponse` (waits for completion); `migrations-dry-run.yml` invokes with `InvocationType=DryRun` (read-only sanity check that the Lambda contract is honored without applying any changes).

Why split into two recipes: orion-backend's CD calls the migration Lambda inline after SAM deploy, but only on push to main. When ops needs to apply migrations out-of-band (a hotfix in the middle of the night, or a status check before approving a prod deploy), there's no first-class trigger — `migrations.yml` + `migrations-dry-run.yml` fill that gap.

Inputs (highlights; both files share the same schema):

| Input | Type | Notes |
|---|---|---|
| `environment-name` | string | Becomes the GH Environment gate. |
| `function-name` | string | Lambda name or ARN. |
| `payload-file` | string | Path to a JSON payload file (relative to `working-directory`). Empty = use `{}`. |

Required secrets: `AWS_DEPLOY_ROLE_ARN`.

#### `seed-users-advisors.yml` / `seed-users-agents.yml` / `seed-users-supervisors.yml`

Three sibling recipes that invoke the `orion-seed-users-<env>` Lambda with payload `{"group": "advisors" | "agents" | "supervisors"}` to seed the corresponding role users in `identity.users`. The Lambda returns `{created, skipped, errors}`; the recipes parse that shape and print a one-line summary.

Why three recipes instead of one parameterized by `group`: each recipe owns its own job display name, step labels, summary parser, and concurrency group, so seeding advisors does not block seeding supervisors or agents. The shared OIDC + invoke bits are copy-pasted because YAML does not support cross-file includes and nested reusables add non-trivial debugging cost for marginal DRY benefit at this size.

Inputs (shared):

| Input | Type | Notes |
|---|---|---|
| `environment-name` | string | Becomes the GH Environment gate. |
| `aws-region` | string | `us-east-1` |
| `function-name` | string | Lambda name (default: `orion-seed-users-<env>`). |

Required secrets: `AWS_DEPLOY_ROLE_ARN`.

### Other files in `.github/workflows/`

These three workflows are **not** part of the consumer-facing catalog; they only run on this repo itself:

- `ci.yml` — Pull request-triggered lint & security pass. Calls the catalog's own quality recipes (`actionlint`, `gitleaks`, `yamllint`, `quality`) against this repository so a broken recipe is caught here before consumers break. The python/node/deploy recipes (`python-ci`, `eslint`, `node-test`, `sam-deploy`, `container-deploy-ecr`, `terraform-plan`, `terraform-apply`, `terraform-destroy`) are NOT exercised here because this repo has no Node project, SAM stack, Python package, or Terraform module to lint; they are validated directly by the consumer repos that invoke them (see `docs/VERSIONING.md` § strategy).
- `codeql.yml` — CodeQL analysis on GitHub Actions YAML. Runs on push to `main`, on pull requests, and weekly.
- `release-please.yml` — release-please automation. Cuts a "release PR" on every push to `main`; merging the release PR creates the git tag + GitHub Release. Configured via `.github/release-please-config.json` + `.release-please-manifest.json`.

The LaTeX reusables (`latex-build.yml`, `latex-release.yml`) ARE catalog recipes but belong to the `07-article` repository's toolchain; they are not part of the orion stack. Same applies to the SonarCloud wrappers (`sonar-python.yml`, `sonar-terraform.yml`, `sonar-typescript.yml`), which target the SonarCloud org's Python/Terraform/TypeScript projects; and to the migration + seed-users recipes (`migrations.yml`, `migrations-dry-run.yml`, `seed-users-*.yml`) + `aws-lambda-invoke.yml`, which target `orion-backend` / `orion-identity` deployments specifically.

## Versioning

See [`docs/VERSIONING.md`](docs/VERSIONING.md). Summary:

- All callers pin `@main` regardless of target environment; the dev/prod distinction lives in the caller's `environment-name` input (GH Environment gate) and per-environment deploy role ARN secret. See `docs/VERSIONING.md` § "Modelo" for the full rationale.
- No SemVer in the short term. Breaking changes are communicated by PR + release notes; consumer repos update their pin as part of their normal cadence.
- All deploy recipes use the **same secret-name convention** (e.g. `AWS_DEPLOY_ROLE_ARN`, `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`) so cross-owner callers can pass them explicitly and bypass the `secrets: inherit` block GitHub applies between different owners.
- The org uses a **single-branch model** (`main`-only) since 2026-Q3. There is no `dev` branch and no promotion step. See [Contributing → Workflow](#workflow) for the PR-driven flow.
- Current catalog: cache-key convention **v4** is the most recent explicit version bump. Since v4 the catalog has grown additively via Sprints A/B/C/D — see [`docs/VERSIONING.md`](docs/VERSIONING.md) for the changelog and [`docs/PYTHON-CI.md`](docs/PYTHON-CI.md) § 8 for the `python-ci.yml` recipe-specific history.

## Cache key convention

All node-consuming recipes (`eslint.yml`, `angular-spa-deploy.yml`,
`sam-deploy.yml`, `node-test.yml`) use the canonical cache key:

```
<os>-node-<nodeVersion>-<pkgmanager>-<env>[-<recipeTag>]-<H>
```

- `os` lowercased (`linux`/`windows`/`macos`).
- `nodeVersion` (e.g. `24`).
- `pkgmanager` (`npm` | `pnpm` | `yarn` | `bun`).
- `env` lowercased (`dev` | `prod` | `ci`).
- `recipeTag` recipe-specific (only `eslint.yml` uses it, for ESLint major isolation).
- `<H>` is `sha256(<lockfile-name>)` of a single file (no glob).

Compared to v3, this:
- drops `setup-node@v7`'s built-in cache (which would produce a conflicting `node-cache-<os>-<arch>-<pkgmgr>-<H>` key lacking `env` and `nodeVersion`).
- lowercases OS so `linux-` and `Linux-` don't produce two cache blobs for the same content.
- includes `pkgmanager` so npm and pnpm consumers don't share keys.
- includes `env` so dev and prod are isolated per GH Environment.

### Rate limits and capacity

GitHub Actions cache has two limits to design around:

| Limit | Value | Source |
|---|---|---|
| **Per-repo cache size cap** | 10 GB (default; org can raise via plan-specific settings) | [GitHub Docs: Caching dependencies to speed workflows → Limitations](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-workflows#limitations) |
| **Cache restore time** | Soft target: < 30 s for a healthy blob; > 60 s = cache miss suspected | Observed on consumer runners |
| **Cache eviction** | LRU after the cap is hit; recent keys survive, old keys silently dropped | GitHub Docs |
| **Best-practice cap on key cardinality** | Keep the key space below a few hundred unique entries per repo. Each unique `(<os>, <nodeVersion>, <pkgmanager>, <env>, <H>)` tuple is a separate blob. | Org experience; LRU eviction is silent |

Practical guidance for this catalog:

- **Per-recipe keys, not per-workflow**. Each recipe that caches should have its own `cache-suffix` segment (today only `eslint.yml` uses `recipeTag`; consider adding it to other recipes when rolling a major tool version).
- **Bump cache on tool upgrade, not on lockfile hash alone**. A `node-version` or `eslint-version` bump should produce a new key, not silently re-use the old blob with stale binaries.
- **Watch the `<H>` segment**. `sha256(package-lock.json)` means any change to `package-lock.json` (even unrelated deps) invalidates the cache. That's intentional — we want the cache to mirror the exact deps in use — but be aware that a routine `npm i` that touches the lockfile invalidates everything.
- **If a repo is approaching the 10 GB cap**, the most likely culprit is per-branch or per-PR cache keys leaking. The v4 convention deliberately keeps the key space small (no per-PR segment) to avoid this.

Full rationale, examples, extension guide, and migration notes:
[`docs/CACHE.md`](docs/CACHE.md).

## Operational scripts

The `scripts/` directory holds 3 entries: 2 idempotent bash bootstrappers and 1 stdlib-only Python guard. Scripts require `gh` CLI authenticated with org admin, support `--dry-run`, and respect `ORG=...` overrides.

| Script | Type | Purpose | Required by a workflow? |
|---|---|---|---|
| [`check_lambda_permission_source_arn.py`](scripts/check_lambda_permission_source_arn.py) | Python | SAM guard: every `AWS::Lambda::Permission` resource in scanned paths must declare `SourceArn:` or `SourceAccount:`. Stdlib-only; regex-based; comment-aware. | **Yes** — consumed by `.github/workflows/lambda-permission-source-arn.yml` (curl from raw @main) |
| [`configure-merge-methods.sh`](scripts/configure-merge-methods.sh) | Bash | Applies squash-only merge policy across every repo in the org (`delete_branch_on_merge=true`, `squash_merge_commit_title=PR_TITLE`, `squash_merge_commit_message=PR_BODY`). | No |
| [`configure-repo-rulesets.sh`](scripts/configure-repo-rulesets.sh) | Bash | Declarative reconciler. Reads `governance/repository-governance.json` and reconciles each repo's ruleset to the desired state. Supports `--check`, `--apply`, `--dry-run`, `--repos`, `--strict`, `--prune-unexpected`, `--json`. Backs up the current ruleset before any `PUT` and never uses `DELETE` unless `--prune-unexpected` is passed. | No |

See [`scripts/README.md`](scripts/README.md) for per-script usage, full flag list, and the convention for adding new entries.

## Governance

The `spark-match` org uses **declarative governance**: the desired state lives in [`governance/repository-governance.json`](governance/repository-governance.json), validated against a JSON Schema in [`governance/repository-governance.schema.json`](governance/repository-governance.schema.json) (validated by `.github/workflows/quality.yml` on every PR). The reconciler (`scripts/configure-repo-rulesets.sh`) brings each repo's actual state in line with the manifest.

The full narrative reference — including rationale, deviation log, and the 6-point compliance checklist — lives in [`docs/GOVERNANCE-STANDARD.md`](docs/GOVERNANCE-STANDARD.md).

### What the ruleset enforces

Every `spark-match/*` repo runs the same `spark-match-default-branch-protection` ruleset:

- **Squash-only merges** (`allowed_merge_methods: ["squash"]`).
- **CODE OWNERS review required** (`require_code_owner_review: true`).
- **No force-pushes** (`non_fast_forward: present`, `required_linear_history: present`).
- **No branch deletion via API** (`deletion: present`).
- **Status checks per-repo** (`required_status_checks` keyed by the per-repo list in the manifest).
- **Admin bypass scoped to pull-request context only** (`bypass_actors[0].bypass_mode: "pull_request"`, not `"always"`). Direct pushes to `main` are blocked.

### Current compliance (snapshot 2026-07-26)

9 of 9 repos compliant on the 5 hard criteria (bypass, squash, deletion, code-owner review, explicit CODEOWNERS paths). 1 of 9 (`spark-match-01-devops`) at full 6/6 since its header wording was aligned to "ruleset"; the other 8 still have the legacy "branch protection" wording in their CODEOWNERS header comment, which is a cosmetic drift documented in `docs/GOVERNANCE-STANDARD.md` § 8.

### Quick commands

```bash
# Audit one repo:
./scripts/configure-repo-rulesets.sh --check --repos spark-match-01-devops

# Apply the manifest to one repo (backs up + PUT):
./scripts/configure-repo-rulesets.sh --apply --repos spark-match-01-devops

# Dry-run across the whole org:
for r in spark-match-{00-knowledge-base,01-devops,02-infrastructure,03-backend,04-frontend,05-data-pipeline,06-model-training,07-article,08-deep-agent}; do
  ./scripts/configure-repo-rulesets.sh --dry-run --repos "$r"
done
```

## Testing

The repo ships with **139 tests** that run on every PR via `.github/workflows/quality.yml` and can be executed locally before pushing:

| Suite | Count | File | What it covers |
|---|---|---|---|
| bats — composite actions | 33 | `tests/bats/composite-validate.bats` (24) + `tests/bats/composite-run-pytest.bats` (9) | Input validation (REQUIRED / ENUM / PATTERN) and pytest arg assembly |
| bats — merge-methods | 11 | `tests/bats/merge-methods.bats` | `configure-merge-methods.sh`: -F booleans, gh failure propagation, --help exit 0 |
| bats — reconciler | 52 | `tests/bats/reconciler-{prereqs,payload,check,apply,edge-cases}.bats` | Arg parsing, manifest validation, payload construction (jq), `--check` mode, `--apply` mode with PUT/POST/backup/dry-run, edge cases (team-id cache, CRLF, `--org` override) |
| bats — release-please | 16 | `tests/bats/release-please-config.bats` | `.github/release-please-config.json` (PR title pattern, header/footer, changelog sections, schema validation, version pin) |
| bats — workflow hygiene | 12 | `tests/bats/cleanup-batch-pr8.bats` | defaults.run.shell: bash on every workflow; terraform-destroy permissions; environment-name input alias; no `shell: bash` inside workflow_call.inputs |
| pytest | 15 | `tests/python/test_lambda.py` | `check_lambda_permission_source_arn.py` over 5 SAM template fixtures under `tests/fixtures/sam-template-*/` |

Shared helpers: `tests/bats/helpers/common.bash` (stubs for `uv` + `pytest`, sets `ACTION_DIR`); `tests/bats/helpers/reconciler.bash` (`gh` stub dispatching on URL + HTTP method, with `json_output` helper for JSON assertions).

### Local setup

```bash
# bats 1.11.1 (one-time install; CI uses the same version):
curl -fsSL https://github.com/bats-core/bats-core/archive/refs/tags/v1.11.1.tar.gz | tar -xz -C /tmp
sudo /tmp/bats-core-1.11.1/install.sh /usr/local
bats --version

# pytest 9.1.1:
pip install pytest==9.1.1

# Optional: jq (bats helpers reference it for VALUE parsing):
# Windows: choco install jq
# macOS:   brew install jq
# Linux:   apt-get install jq
```

### Running locally

```bash
# All tests:
bats tests/bats/
python -m pytest tests/python/ -v

# Just one suite:
bats tests/bats/composite-validate.bats
python -m pytest tests/python/test_lambda.py -v -k TestScanTemplate
```

Expected runtime: < 1 s for bats, < 0.5 s for pytest. CI adds setup overhead (~25 s total per job including bats download + pip install).

### Adding a new test

- For a new bash primitive / composite action → add `tests/bats/<subject>.bats`. Reuse `tests/bats/helpers/common.bash` for `ACTION_DIR` and stub definitions.
- For a new bash script (e.g. a new reconciler / bootstrapper) → add `tests/bats/reconciler-<aspect>.bats` and reuse `tests/bats/helpers/reconciler.bash` for the `gh` stub.
- For a new Python script → add `tests/python/test_<subject>.py`. Reuse `tests/fixtures/<case>/template.yaml` patterns.

The CI workflow auto-discovers `tests/bats/*.bats` and `tests/python/test_*.py`, so no other configuration is needed.

## Contributing

The org uses a **single-branch model** (`main`-only) since 2026-Q3. All changes target `main` directly via pull request; there is no `dev` branch and no promotion step. The ruleset enforces 1 CODE OWNERS approval plus the strict status check list, so every PR runs the full CI matrix before merge.

### Workflow

1. Branch from `main` with a Conventional Commits scope (`chore(cookbook): ...`, `feat(node): ...`, `fix(deploy): ...`, `test(composite): ...`, etc.).
2. Open a pull request against `main`. Code owners are requested automatically via `.github/CODEOWNERS` (rule `require_code_owner_review: true`).
3. Wait for `ci.yml` (actionlint + gitleaks + yamllint + quality) to be green and at least one CODE OWNER approval.
4. Merge with `gh pr merge --squash --admin --delete-branch`. The ruleset deletes the branch on merge automatically.
5. **Self-approval is impossible** even when you are the only CODE OWNER. If you are the sole reviewer, ask another team member or use the admin-bypass dance below.

### Admin bypass (rare; use sparingly)

The ruleset blocks direct pushes to `main` for everyone, including org admins, because `bypass_mode: "pull_request"` only covers the PR context. The escape hatch is the **dual-disable + direct push dance**, used for emergency hotfixes and CODE OWNERS migrations:

1. Temporarily flip the ruleset's `bypass_actors[0].bypass_mode` to `"always"`.
2. Temporarily DELETE the legacy branch protection's `enforce_admins` flag.
3. Direct push to `main`.
4. Restore both flags to their canonical state (`bypass_mode: "pull_request"` and `enforce_admins: true`).
5. Verify with `./scripts/configure-repo-rulesets.sh --check`.

The whole window must be < 5 seconds in production. Document the dance (per repo, never in this public repo) and never use it for ordinary PR work. CODE OWNERS review applies even when `bypass_mode: "always"` if the author is itself a CODE OWNER — in that case, push from a non-CODE-OWNER account or temporarily add the path as `* @devops`.

### Adding a reusable workflow or composite action

For workflows:

- Place the file at the top level of `.github/workflows/`. Subfolders break `uses: ./...`.
- Re-declare `permissions` for whatever the recipe needs (`contents: read`, `id-token: write`, etc.).
- For deploy recipes, declare secrets by explicit name and follow the same-name convention used by existing deploy recipes.
- Update `docs/VERSIONING.md` if the recipe introduces a new convention.

For composite actions:

- Place the action at `.github/actions/<name>/action.yml`. The convention is one directory per action.
- Add bats tests at `tests/bats/<name>.bats` reusing `tests/bats/helpers/common.bash`.
- If the action accepts an enum / pattern / required input, wire it through `validate-workflow-inputs` as the first step of every workflow that calls it.

### Bumping external tool versions

Routine bumps are handled automatically by **Dependabot** (`.github/dependabot.yml`): weekly Monday 06:00 UTC, 5 groups (aws-actions, actions-ecosystem, marocchino, release-tools, third-party-actions). Each PR has `ahincho` as assignee and `@spark-match/devops` as reviewer. Commit prefix `ci(deps):`.

When **manually** bumping (e.g. when changing the version a recipe defaults to):

- Pin `actionlint` to a release tag (never `main`).
- Pin `yamllint` to `1.35.1` unless the team agrees to migrate to the v2 rewrites.
- Update the recipe header comment + the catalog's `README.md` "Catalog" section.
- Open a PR; the Dependabot workflow picks up downstream version pinning.

## Security

The repo is the org-wide CI/CD catalog, so a security defect here
propagates to every `spark-match/*` consumer. The toolchain is
layered: cheap static checks on every PR, deeper analysis on push
and weekly.

### Layered toolchain

| Tool | Scope | Trigger | Status | Where |
|---|---|---|---|---|
| **actionlint** | Actions YAML syntax | every PR + push | required check | `.github/workflows/actionlint.yml` |
| **yamllint** | YAML style + parse | every PR + push | required check | `.github/workflows/yamllint.yml` |
| **gitleaks** | secret scan over git history | every PR + push | required check (org-scoped) | `.github/workflows/gitleaks.yml` |
| **CodeQL** | `actions/*` rules (code-injection, unpinned-tag, envvar-injection) | every PR + push + weekly | informational | `.github/workflows/codeql.yml` |
| **Dependabot** | weekly bump PRs for GitHub Actions | Mon 06:00 UTC | enabled | `.github/dependabot.yml` |
| **Dependabot security updates** | auto-PR for known-vulnerable dependencies | on alert | enabled | repo-level (set via `PATCH .../dependabot_security_updates`) |
| **Secret scanning** | native GH secret detection | always | **disabled** (requires GHAS paid plan) | n/a |
| **Push protection** | block pushes that contain secrets | always | **disabled** (requires GHAS paid plan) | n/a |

### CodeQL posture (snapshot 2026-07-29)

After Sprint A + B + C (PRs #148-#157):

| Rule | Alerts opened | Alerts fixed |
|---|---|---|
| `actions/unpinned-tag` | 71 | 71 (SHA-pinning) |
| `actions/code-injection/medium` | 410 | 410 (env-isolation) |
| `actions/envvar-injection/medium` | 6 | 6 (newline strip + `$GITHUB_ENV` write pattern) |
| **Total** | **502** | **502 (100%)** |

### Secret scanning: paid-plan limitation

The `spark-match` organization is on **GitHub Free**. The following
features require **GitHub Advanced Security** (paid, per-user):

- `secret_scanning` (provider patterns + non-provider patterns)
- `secret_scanning_push_protection`
- `secret_scanning_validity_checks`

These are configured off at the repo level (`security_and_analysis`
shows `disabled`). We work around this with:

1. **`gitleaks.yml`** runs on every PR + push, scanning the full
   git history. This catches the same set of secrets as native
   secret scanning plus custom patterns.
2. **CODEOWNERS** + `require_code_owner_review: true` ensures a
   human reviews every line before merge.
3. **Strict secrets policy**: no `.env` files in the repo, all
   secrets in `gh secret set` or GitHub Actions secrets, never
   echoed in `run:` blocks (see `.github/workflows/release-please.yml`
   for the template).

If you find a leaked secret in git history:

1. **Rotate the secret immediately** (do not wait for a PR).
2. Open a private Security Advisory (see [SECURITY.md](SECURITY.md)).
3. The team will coordinate history rewriting (`git filter-repo`) and
   key rotation across all consumers.

### If you fork or upgrade to GitHub Team / Enterprise

Upgrading `spark-match` to GitHub Team ($4/user/month) unlocks:

- **Secret scanning** with provider patterns (AWS keys, GitHub PATs, etc.)
- **Push protection** (block `git push` containing a secret)
- **Validity checks** (alert only if the leaked credential is still active)

To enable after upgrade:

```bash
gh api -X PATCH /repos/spark-match/spark-match-01-devops \
  --input enable-ghas.json
```

`enable-ghas.json`:

```json
{
  "security_and_analysis": {
    "secret_scanning": {"status": "enabled"},
    "secret_scanning_push_protection": {"status": "enabled"},
    "secret_scanning_validity_checks": {"status": "enabled"}
  }
}
```

Then remove the gitleaks workaround from the catalog or keep it as
defense-in-depth (recommended).

## License

GNU General Public License v3.0 or later ([`LICENSE`](LICENSE)). All source files carry SPDX-License-Identifier headers (`GPL-3.0-or-later`). Copyleft: derivative works must also be GPL-3.0+ when distributed.

Prior to 2026-07-26 this repo was Apache-2.0. The change was driven by the catalog's role as infrastructure that other `spark-match/*` repos consume: copyleft ensures the recipes stay free and that improvements flow back to the community. See [CHANGELOG.md](CHANGELOG.md) for the migration entry.

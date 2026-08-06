# Spark Match DevOps

Central repository for CI/CD pipelines, GitHub governance, and quality tooling for the `spark-match` organization. This repo is the **single source of truth** for shared automation that consumer repositories call via reusable workflows and composite actions.

## Quick start

Pick the path that matches what you need:

| You want to… | Do this |
|---|---|
| **Deploy a Terraform stack** | Call `reusable-terraform-plan.yml` / `reusable-terraform-apply.yml` / `reusable-terraform-destroy.yml` with OIDC + a GitHub Environment |
| **Apply the org ruleset to a new repo** | Add an entry to `governance/repository-governance.json`, then `./scripts/configure-repo-rulesets.sh --apply --repos <name>` ([Governance](#governance)) |
| **Add a new reusable workflow** | See [Contributing → adding a recipe](#adding-a-reusable-workflow-or-composite-action) |
| **Run the tests locally before pushing** | See [Testing](#testing) |

## Architecture

The catalog has **seven layers**, each defined by what it inspects or mutates:

| Layer | Path | Caller secrets | Purpose |
|---|---|---|---|
| **composite actions** | `.github/actions/<name>/action.yml` | varies | Atomic, single-purpose primitives reusable across many recipes (input validators, runners) |
| **ecosystem workflows** | `.github/workflows/reusable-<ecosystem>.yml` | none | Read-only checks against caller code (actionlint, gitleaks, trivy, yamllint, terraform-*, sonar-*, etc.) |
| **node workflows** | `.github/workflows/reusable-<node>.yml` | none | npm-based quality gates (eslint, typecheck, test, build) |
| **python workflows** | `.github/workflows/reusable-<python>.yml` | none | uv + ruff + mypy + pytest, sonar-python quality gate |
| **deploy workflows** | `.github/workflows/reusable-<deploy>.yml` | OIDC role per GH Environment | Production deploys (Terraform, container push to ECR) |
| **governance** | `governance/` + `scripts/configure-repo-rulesets.sh` | `gh` admin scope | Declarative state for the org ruleset + idempotent reconciler |

Every recipe (workflow and composite action) accepts an `environment-name` input. It is informational in ecosystem, node, python, and composite layers (used in job name and step logs), and gates the job on a GitHub Environment in deploy recipes (caller must define the environment and put the OIDC role secret there).

### Quality and governance as code

This repo also ships:

- **`governance/repository-governance.json`** — declarative desired state of the org ruleset across all `spark-match/*` repos.
- **`scripts/configure-repo-rulesets.sh`** — idempotent reconciler: reads the manifest, computes drift, applies via `POST` / `PUT`, backs up before any mutation. Supports `--check`, `--apply`, `--dry-run`, `--repos`, `--strict`, `--prune-unexpected`, `--json`.
- **`tests/`** — 492 bats tests, all running on every PR via `.github/workflows/reusable-quality.yml`.
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
│   │   └── validate-workflow-inputs/        JSON-schema-driven input validation (REQUIRED / ENUM / PATTERN)
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
│       ├── codeql-actions.yml               codeql on Actions YAML (push + weekly)
│       ├── release-please.yml               release-please automation (cuts release PRs)
│       ├── commitlint.yml                   commitlint check on every PR + push
│       ├── sbom.yml                         cyclonedx sbom attached to GH Release
│       │
│       │ ─── catalog recipes (reusables, called via uses: from consumer repos) ──
│       │ ─── prefix `reusable-` flags the workflow_call entrypoint ─────────────
│       │
│       │ ─── catalog: ecosystem (read-only, no caller secrets) ──────────
│       ├── reusable-actionlint.yml          syntax check on Actions workflows
│       ├── reusable-gitleaks.yml            secret scan (needs GITLEAKS_LICENSE)
│       ├── reusable-trivy.yml               filesystem / image / IaC vuln scan (aquasecurity/trivy-action)
│       ├── reusable-yamllint.yml            YAML files (uses caller's .yamllint.yml)
│       ├── reusable-terraform-validate.yml  per-module init+validate (no backend)
│       ├── reusable-tflint.yml              recursive tflint
│       ├── reusable-sonar-terraform.yml     sonar-cloud terraform analysis
│       ├── reusable-sonar-typescript.yml    sonar-cloud typescript analysis
│       ├── reusable-sonar-python.yml        sonar-cloud python analysis (Cobertura coverage)
│       ├── reusable-quality.yml             shellcheck + manifest schema + bats
│       ├── reusable-codeql.yml              codeql for JS/TS caller repos
│       │
│       │ ─── catalog: node (npm, no caller secrets) ───────────────────────
│       ├── reusable-eslint.yml              `npm run <lint-script>`
│       ├── reusable-node-test.yml           `npm run <test-script>` with cache
│       ├── reusable-node-typecheck.yml      `npm run <typecheck-script>` with cache
│       ├── reusable-node-build.yml          `npm run <build-script>` with cache
│       │
│       │ ─── catalog: python (uv, no caller secrets) ─────────────────────
│       ├── reusable-python-ci.yml           uv sync + ruff + mypy + pytest + coverage report
│       │
│       │ ─── catalog: deploy (AWS OIDC, caller-scoped secrets) ──────────
│       ├── reusable-migrations-dry-run.yml  migration dry-run against ephemeral Postgres (read-only)
│       ├── reusable-terraform-plan.yml      `terraform plan` per env + sticky PR comment
│       ├── reusable-terraform-apply.yml     `terraform apply`, optional drift-only mode
│       ├── reusable-terraform-destroy.yml   `terraform apply -destroy`, double-gated by
│       │                                   confirm-destroy-token (DESTROY-<ENV>) and
│       │                                   optional GH Environment approval + post-destroy
│       │                                   cleanup job (CLEANUP-<ENV>)
│       ├── reusable-container-deploy-ecr.yml docker buildx + ECR push via OIDC (linux/arm64 by default)
│       ├── reusable-ecs-deploy.yml         register task definition revision + roll the ECS
│       │                                   service onto an image already in ECR
│       │
│       │ ─── catalog: article (latex, kept for 07-article's toolchain) ────
│       ├── reusable-latex-build.yml         compile latex -> PDF artifact
│       └── reusable-latex-release.yml       bump patch + GitHub Release
│
├── docs/
│   ├── CACHE.md                            canonical cache-key convention v4 + rate-limit guidance
│   ├── GOVERNANCE-STANDARD.md              org-wide ruleset + CODEOWNERS standard
│   └── VERSIONING.md                       pin-by-environment rules and conventions
│
├── governance/
│   ├── repository-governance.json          desired state of org ruleset (schema v2)
│   └── repository-governance.schema.json   Draft 2020-12 schema; validated by reusable-quality.yml
│
├── scripts/                                operational scripts (see scripts/README.md)
│   ├── README.md                           catalog of scripts
│   ├── audit-codeowners-ruleset.sh             audits ruleset for CODE_OWNERS enforcement
│   └── configure-repo-rulesets.sh              declarative reconciler for the ruleset
│
├── tests/                                 bats tests for bash scripts + composite actions
│   ├── bats/
│   │   ├── helpers/
│   │   │   ├── common.bash                 stub utilities for composite-action tests + ACTION_DIR
│   │   │   └── reconciler.bash             gh stub dispatching on URL + HTTP method
│   │   ├── composite-validate.bats         24 tests for validate-workflow-inputs
│   │   ├── reconciler-prereqs.bats         10 tests for arg parsing + manifest + gh auth
│   │   ├── reconciler-payload.bats         9 tests for build_desired_payload jq
│   │   ├── reconciler-check.bats           11 tests for --check mode
│   │   ├── reconciler-apply.bats           16 tests for --apply mode (PUT/POST/backup)
│   │   ├── reconciler-edge-cases.bats      6 tests for team cache + CRLF + --org override
│   │   ├── release-please-config.bats      16 tests for .github/release-please-config.json
│   │   └── cleanup-batch-pr8.bats          12 tests for PR-8 defaults.run.shell + prs:write + env-name
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

JSON-Schema-driven validator that gates a workflow step on the validity of its inputs. Fails fast with `::error::` annotations so the workflow exits at the first invalid input rather than producing confusing downstream errors. Used by `reusable-quality.yml` to gate every `shellcheck-severity`, `schema-strict`, and similar enum input.

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

## Catalog

The recipes live at the top level of `.github/workflows/`. GitHub Actions requires reusable workflows at the top level, so the four workflow layers (ecosystem, node, python, deploy) are encoded by naming and ordering rather than by subdirectory. Composite actions (see above) live under `.github/actions/` instead.

### ecosystem

| Recipe | Purpose | Caller secrets |
|---|---|---|
| `reusable-actionlint.yml` | Validate GitHub Actions syntax | — |
| `reusable-gitleaks.yml`   | Scan git history for accidentally committed secrets (pinned to `gitleaks/gitleaks-action@v3`) | `GITLEAKS_LICENSE` (required for org-scoped repos under v3) |
| `reusable-trivy.yml`      | Filesystem / image / IaC vulnerability scan via Aqua Trivy (default: fail on CRITICAL; HIGH configurable) | — |
| `reusable-yamllint.yml`   | Lint non-workflow YAML files (SAM templates, Terraform configs, etc.); pinned to yamllint 1.35.1 | — |
| `reusable-terraform-validate.yml` | `terraform init -backend=false` + `terraform validate` for every auto-discovered module | — |
| `reusable-tflint.yml`            | `tflint --recursive` using caller's `.tflint.hcl` config | — |
| `reusable-sonar-terraform.yml`   | sonar-cloud Terraform analysis | `SONAR_TOKEN` |
| `reusable-sonar-typescript.yml`  | sonar-cloud TypeScript analysis (LCOV) | `SONAR_TOKEN` |
| `reusable-sonar-python.yml`      | sonar-cloud Python analysis (Cobertura XML coverage) | `SONAR_TOKEN` |
| `reusable-quality.yml`           | shellcheck + manifest schema + bats | — |
| `reusable-codeql.yml`            | codeql JS/TS caller-repo scan | — |
| `reusable-commitlint.yml`        | Conventional Commits check on the PR's commits | — |
| `reusable-release-please.yml`    | Cut and maintain the release pull request; tag on merge | `release-please-app-id`, `release-please-app-private-key` |

#### `reusable-actionlint.yml`

Validates `.github/workflows/*.yml` in the caller. Downloads the actionlint binary pinned to `v1.7.7` (avoid tracking `main` for supply-chain safety).

Inputs:

| Input        | Type   | Default | Notes                                                |
|--------------|--------|---------|------------------------------------------------------|
| environment-name | string | `dev` | Informational only; used in the job name and logs. |

Usage:

```yaml
jobs:
  actionlint:
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-actionlint.yml@main
    with:
      environment-name: ci
```

#### `reusable-gitleaks.yml`

Runs secret scanning against the full git history. Pinned to `gitleaks-action@v3`; for org-scoped repos callers MUST forward the `GITLEAKS_LICENSE` secret (free at gitleaks.io) because GitHub drops `secrets: inherit` across owner boundaries. The org-level Dependabot secret bucket holds `GITLEAKS_LICENSE` (visibility: all-repos) so Dependabot-triggered runs see it without per-repo setup.

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | `dev` | Informational only. |

Usage:

```yaml
jobs:
  gitleaks:
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-gitleaks.yml@main
    with:
      environment-name: ci
```

#### `reusable-yamllint.yml`

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
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-yamllint.yml@main
    with:
      environment-name: ci
```

#### `reusable-terraform-validate.yml`

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
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-terraform-validate.yml@main
    with:
      environment-name: dev
      terraform-version: 1.15.7
```

#### `reusable-tflint.yml`

Runs `tflint --recursive` against the caller's Terraform code. Caller must provide a `.tflint.hcl` at the repo root — tflint reads it per-subdirectory and follows the plugin set declared there.

Pins:

- `terraform-linters/setup-tflint@v6` (bumped from v4 in a `spark-match-02-infrastructure` PR)
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
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-tflint.yml@main
    with:
      environment-name: dev
```

#### `sbom-release.yml`

Internal workflow (not a reusable recipe — runs only on this catalog). Fires on `release: { types: [published] }` (i.e. after `release-please` publishes a tagged release) and generates a cyclonedx JSON sbom using [`anchore/sbom-action`](https://github.com/anchore/sbom-action). The sbom is checked in at the tagged commit (not main HEAD) and uploaded to the GitHub Release as `sbom.cdx.json`. Manual re-run via `workflow_dispatch` accepts a `tag:` input.

`permissions: contents: write` is required (upload needs write); `id-token`, `packages`, and `deployments` are explicitly NOT requested.

This workflow is part of the SLSA Build Level 3 + supply-chain transparency posture (US Executive Order 14028, EU Cyber Resilience Act). For a repo with no real `package.json` / `requirements.txt` the sbom is metadata-only, but it is still produced and attached.

#### `reusable-sonar-terraform.yml`

sonar-cloud analysis for Terraform. Designed for projects where Terraform is the primary language (no Python/JS).

Every input is **required** — none has a default. Passing an input that is not
on this list fails the caller's workflow outright with `Invalid input`, and
omitting one fails it too, so this table is exhaustive rather than
"highlights".

| Input | Type | Notes |
|---|---|---|
| `project-key` | string (required) | sonar-cloud project key. |
| `project-name` | string (required) | sonar-cloud project display name. |
| `organization` | string (required) | sonar-cloud organization key. |
| `sources` | string (required) | Comma-separated source paths (relative to `working-directory`). |
| `exclude-patterns` | string (required) | Comma-separated globs to exclude from sources. |
| `working-directory` | string (required) | Directory containing the Terraform code. |
| `env` | string (required) | Environment identifier; used in the job name and logs. |
| `fail-on-quality-gate` | string (required) | `"true"` fails the job when the quality gate is ERROR. A string, not a bool. |

There is no `sonar-host-url` input: the recipe targets sonar-cloud and the host
is not configurable. There is no `tests` or `coverage` input either — this
recipe analyses Terraform, which has no test or coverage report to feed
sonar-cloud. Those three were documented here for a while and never existed.

Required secrets: `SONAR_TOKEN` (same-name convention). Caller must set it in the GitHub Environment.

#### `reusable-sonar-typescript.yml`

sonar-cloud analysis for TypeScript. Used by `spark-match-04-frontend`. Unlike
the Terraform wrapper, this one installs dependencies and runs the caller's test
command first, so it can hand sonar-cloud a real LCOV coverage report.

All 16 inputs are **required** — none has a default. There is no `tsconfig-path`
input; the string `tsconfig` does not appear anywhere in the recipe.

| Input | Notes |
|---|---|
| `project-key` | sonar-cloud project key. |
| `project-name` | sonar-cloud project display name. |
| `organization` | sonar-cloud organization key. |
| `sources` | Comma-separated source paths, relative to `working-directory`. |
| `tests` | Comma-separated test directory paths. |
| `test-inclusions` | Glob identifying test files inside those directories. |
| `exclude-patterns` | Globs excluded from both sources and tests. |
| `working-directory` | Directory holding `package.json`. |
| `env` | Environment identifier; used in the job name and logs. |
| `node-version` | Node.js version. |
| `package-manager` | Hint for the setup-node cache: `npm`, `pnpm`, `yarn` or `bun`. |
| `lockfile-name` | Lockfile used as the cache key, relative to `working-directory`. |
| `install-command` | e.g. `npm ci`, `pnpm install --frozen-lockfile`. |
| `test-command` | Must produce LCOV coverage. |
| `coverage-paths` | Comma-separated LCOV report paths. |
| `fail-on-quality-gate` | `"true"` fails the job when the gate is ERROR. A string, not a bool. |

#### `reusable-codeql.yml`

codeql analysis for caller repos with JS/TS source. This repo scans its own
Actions YAML through `codeql-actions.yml` instead, which is not this recipe.

| Input | Type | Default | Notes |
|---|---|---|---|
| `languages` | string | `javascript` | Comma-separated codeql languages; drives the analysis matrix. |
| `build-mode` | string | `none` | `none` or `autobuild`. |
| `queries-pack` | string | `security-extended` | Query pack to run. |
| `fail-on-alerts` | boolean | `true` | Exit non-zero when alerts at or above `fail-on-severity` exist. |
| `fail-on-severity` | string | `warning` | `error`, `warning` or `note`. |
| `config-file` | string | `''` | Optional codeql config YAML in the caller repo. |

Needs no secrets: it works off `security-events: write` on `GITHUB_TOKEN`. The
`secrets:` block declares a single empty entry named `pass` as a placeholder, so
callers should not try to pass anything to it.

One job per language, named `analyze-<language>`.

#### `reusable-quality.yml`

The three self-checks this repo runs on itself: shellcheck over `scripts/` and
the composite actions, JSON Schema validation of the governance manifest, and
the bats suite.

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | `dev` | Informational, and appended to all three job names. |
| `shellcheck-severity` | string | `warning` | `warning`, `error`, `info` or `style`. |
| `schema-strict` | boolean | `false` | When true, schema validation also fails on `additionalProperties`. |

Three jobs: `shellcheck-<environment-name>`, `manifest-schema-<environment-name>`
and `bats-<environment-name>`. The suffix comes from an input, so the contexts
are stable per caller and usable as required checks — this repo passes
`environment-name: ci` and requires `quality / bats-ci`.

#### `reusable-commitlint.yml`

Lints the PR's commit messages against Conventional Commits 1.0.0 using the
caller's `.commitlintrc.json`. Consumed by `01-devops`, `02-infrastructure`,
`03-backend` and `08-deep-agent`.

| Input | Type | Default | Notes |
|---|---|---|---|
| `config-file` | string | `.commitlintrc.json` | Path relative to the repo root. |
| `commit-depth` | number | `2` | How many commits back from the PR head to lint. |
| `help-url` | string | `''` | Shown in the failure report; usually the caller's `AGENTS.md`. |
| `skip-release-please` | boolean | `false` | Skips refs starting with `release-please--`, whose commits this recipe does not author. |

The job is named `commitlint`, with **no** branch or environment suffix, so the
published check context is `<caller-job-id> / commitlint` and stays identical on
every run. That is deliberate and load-bearing: a required status check is
matched by name, so a name that varies per branch can never be satisfied on a
pull request. `tests/bats/reconciler-status-checks.bats` fails if an expression
is reintroduced into the job name.

#### `reusable-release-please.yml`

Runs release-please: maintains an open "release pull request" that accumulates
Conventional Commits into a CHANGELOG entry and a version bump, and on merge
creates the tag plus the GitHub Release. Configured per caller via
`.github/release-please-config.json` and `.release-please-manifest.json`.

Takes **no inputs**, and the two config paths are hardcoded: the caller must
place them at `.github/release-please-config.json` and
`.release-please-manifest.json` exactly.

It mints an installation token with `actions/create-github-app-token@v3` and
hands that to release-please instead of using `GITHUB_TOKEN`. That matters
because GitHub does not fire workflow triggers for events caused by
`GITHUB_TOKEN`: a release pull request opened with it would never run the
caller's own CI, so the release would go out unverified.

The job is named `release-please`, so the check context is
`<caller-job-id> / release-please`.

Required secrets: `release-please-app-id`, `release-please-app-private-key`
(mapped by the caller from the org-level `RELEASE_PLEASE_APP_ID` and
`RELEASE_PLEASE_APP_PRIVATE_KEY`). Both are `required: true`, so a caller that
omits them fails at workflow load.

### node

#### `reusable-eslint.yml`

Runs `npm run <lint-script>` for Node workspaces and caches `~/.npm` keyed on `os-node<node-version>-eslint<eslint-version>-package-lock.json`. Includes `eslint-version` so callers can roll forward to a new eslint major without forking the recipe (cache key changes so no stale cache).

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
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-eslint.yml@main
    with:
      environment-name: ci
      eslint-version: 10
      # lint-script defaults to "lint"
```

#### `reusable-node-test.yml`

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
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-node-test.yml@main
    with:
      environment-name: ci
      test-script: test
      pre-test-script: prebuild
```

#### `reusable-node-typecheck.yml`

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
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-node-typecheck.yml@main
    with:
      environment-name: ci
      # typecheck-script defaults to "typecheck"
```

#### `reusable-node-build.yml`

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
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-node-build.yml@main
    with:
      environment-name: ci
      # build-script defaults to "build"
      # pre-build-script optional (Angular: 'prebuild')
```

### python

#### `reusable-python-ci.yml`

Single-call Python QA pipeline driven by a `commands:` CSV input. Supports
`lint:ruff-format`, `lint:ruff-check`, `lint:bandit`, `typecheck:mypy`,
`test:pytest`, `coverage:report`, `coverage:upload`, `security:pip-audit`,
`lock:check`, and `none`. Default Python version is `3.14` (overridable
via `python-version` input for multi-version testing). Uses `uv` for
dependency management and `ruff` + `mypy` + `pytest` for the QA matrix.
Cobertura-style `coverage.xml` is the canonical artifact (consumed by
`reusable-sonar-python.yml`).

Designed for the first Python consumer in the org, `spark-match-08-deep-agent`,
which has a multi-stage ARM64 Dockerfile on port 8080 (non-root). Pre-deletion
context: PRs #202 / #203 (2026-08-02) removed the original Python reusables
(`python-ci.yml`, `sonar-python.yml`, `trivy.yml`, `container-deploy-ecr.yml`)
and no Python repo in the org could consume CI from the catalog since then.
This PR restores them with the post-cleanup governance applied (floating
action tags, no SHA pins, no `concurrency:` block, env-isolated inputs in
all `run:` blocks).

Inputs (highlights; full list in the file header):

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string (required) | — | Used in job name; informational. |
| `working-directory` | string | `.` | Where `pyproject.toml` lives. |
| `commands` | string (CSV) | full QA | Pipeline steps to run, comma-separated. |
| `python-version` | string | `3.14` | `uv python install` target. |
| `dependency-groups` | string | `dev` | Space-separated `uv sync --group` names. |
| `sync-mode` | choice | `full` | `full` \| `runtime-only` \| `lint-only`. |
| `coverage-threshold` | string | `80` | `coverage report --fail-under`; empty disables. |
| `coverage-output` | string | `coverage.xml` | Cobertura XML path. |
| `lock-check` | bool | `false` | Run `uv lock --check` before sync. |
| `frozen` | bool | `false` | Pass `--frozen` to `uv sync`. |
| `setup-uv-version` | string | `latest` | uv version pin. |
| `cache-suffix` | string | `''` | Falls back to `environment-name` when empty. |
| `permissions-write` | bool | `false` | Opt-in sticky PR coverage comment. |
| `timeout-minutes` | number | `20` | Job-level timeout. |
| `fail-fast` | bool | `false` | Matrix `fail-fast`. |

#### `reusable-sonar-python.yml`

sonar-cloud Python analysis. Symmetric to `reusable-sonar-typescript.yml`
but adapted for Python sources and Cobertura-style coverage XML. Sets
`sonar.python.version=${{ inputs.python-version }}` so SonarCloud can
resolve Python types during analysis.

Inputs (highlights):

| Input | Type | Notes |
|---|---|---|
| `project-key` | string (required) | sonar-cloud project key. |
| `organization` | string (required) | sonar-cloud organization key. |
| `sources` | string (required) | Comma-separated source paths (relative to `working-directory`). |
| `tests` | string (required) | Comma-separated test paths; empty disables test analysis. |
| `working-directory` | string (required) | Where `pyproject.toml` lives. |
| `env` | string (required) | Job-name suffix. |
| `python-version` | string | `3.14` default. |
| `sync-groups` | string (required) | Space-separated `uv sync --group` names. |
| `pytest-targets` | string (required) | Path passed to pytest. |
| `pytest-args` | string (required) | Pass `--cov=<pkg> --cov-report=xml:coverage.xml` to emit Cobertura XML. |
| `coverage-paths` | string (required) | Comma-separated Cobertura report paths for sonar-cloud. |
| `fail-on-quality-gate` | string (required) | `"true"` to fail when quality gate is ERROR. |

Required secrets: `SONAR_TOKEN`.

#### `reusable-trivy.yml`

Filesystem / image / IaC vulnerability scan via Aqua Trivy. Three modes:
`fs` (default; scans the repo filesystem for misconfig + dependency CVEs),
`image` (requires `image-ref`), `config` (Terraform, Kubernetes, Dockerfile).
Default fails on any CRITICAL finding; HIGH configurable via the `severity:`
input. SARIF output (when `format: sarif`) is uploaded to the GitHub
Security tab via `github/codeql-action/upload-sarif`.

Pin: `aquasecurity/trivy-action@v0.36.0` (minor-pinned because the 0.x line
has breaking changes between minors, per AGENTS.md §5.1 exception pattern).
The `v` is not optional — that repository's tags are all `v`-prefixed, and
`@0.36.0` does not resolve.

Inputs (highlights):

| Input | Type | Default | Notes |
|---|---|---|---|
| `scan-type` | choice | `fs` | `fs` \| `image` \| `config`. |
| `scan-ref` | string | `.` | Path to scan (fs / config). |
| `image-ref` | string | `''` | Container image reference (image mode). |
| `severity` | string | `CRITICAL` | Comma-separated severity list (CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN). |
| `format` | choice | `table` | `table` \| `sarif` (uploads to Security tab). |
| `exit-code` | string | `1` | Trivy exit code when vulns match severity. |
| `ignore-unfixed` | bool | `true` | Skip CVEs without released fix. |
| `timeout` | string | `5m0s` | Trivy scan timeout. |
| `scanners` | string (CSV) | `vuln,secret,misconfig` | Activated scanner list. |

### deploy

#### `reusable-terraform-plan.yml`

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

#### `reusable-terraform-apply.yml`

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

#### `reusable-terraform-destroy.yml`

Runs `terraform plan -destroy` then `terraform apply -destroy` per environment. Complementary to `reusable-terraform-apply.yml` — when you need to tear down an environment instead of build it up. Two independent gates prevent fat-finger mistakes:

1. **`confirm-destroy-token` input** — the job aborts unless this input equals exactly `DESTROY-<ENV>` (case-sensitive, all caps). The caller is responsible for collecting this from a human before invoking (typically via `workflow_dispatch` with the `confirm_destroy` field). Failure logs the expected token and the length of what was received (never the value).
2. **`gh-environment` input** — optional approval gate via GitHub Environment. Falls back to `environment`. For non-prod envs that intentionally have no reviewers, set `auto-approve: true`.

The recipe also uploads the **current state as an artifact** before the apply step, so operators can recover from a bad destroy by re-applying against the backup. `dry-run: true` mode plans only without applying (preview what would be removed).

Concurrency: `cancel-in-progress: false` — destroys in flight must complete or be rolled back by hand. Re-running requires the lock to release naturally.

Key inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment | string | `''` (basename of `working-directory`) | Display + concurrency. Also forms the suffix of the required confirm token (`DESTROY-<ENV>`). |
| working-directory | string | `.` | |
| aws-region   | string | `us-east-1` | |
| apply-role-arn-secret | string | `AWS_APPLY_ROLE_ARN` | The role needs admin-equivalent rights; destroy recreates resources. |
| terraform-version | string | `1.10.0` | |
| backend-bucket / backend-key / tfvars-file / var-files / target / extra-args | string | various | Standard passthrough. |
| confirm-destroy-token | string | **REQUIRED** | Must equal `DESTROY-<ENV>` exactly. The caller collects this from a human (typically via `workflow_dispatch`). |
| gh-environment | string | = environment | Approval gate name. |
| auto-approve | bool | `false` | Skip approval (only for non-prod envs with empty reviewers). |
| dry-run | bool | `false` | Plan only — no resources are destroyed. Useful for previewing what would be removed. |
| retention-days | number | `14` | 1-90 (GitHub Actions limits); for the plan artifact and the pre-destroy state backup. |
| project-name | string | `''` (auto-derive from `backend-bucket`) | Used as the filter prefix for log groups (`/aws/lambda/<project>-*`, etc.), SSM parameters (`/<project>/*`), S3 buckets (`<project>-sam-artifacts-*`), and CloudFormation stacks (`<project>-*`). Auto-derived from `backend-bucket` when empty using the pattern `<project>-tfstate-<env>` (so `myapp-tfstate-dev` produces `myapp`). Pass explicitly only if your bucket name does not follow the convention. |
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
- IAM users (e.g. `myapp-admin`) and GitHub-side resources (Secrets, Variables, Environments) are NOT touched.

Caller-side example:

```yaml
jobs:
  destroy:
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-terraform-destroy.yml@main
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

#### `reusable-container-deploy-ecr.yml`

Build a Dockerfile via `docker buildx`, push the result to an ECR
repository (already provisioned via Terraform), and tag it `latest`
plus `<sha>` by default. Designed for ARM64 Bedrock AgentCore workloads
(default `platforms: linux/arm64`); override to `linux/amd64` for x86.
Supports optional `provenance` + SPDX `sbom` attestations (SLSA Build
Level 3) and Sigstore `cosign` keyless signing via Fulcio + OIDC.

Caller supplies the ECR repository name and the OIDC role ARN that has
IAM permission to call the `ecr:*` push permissions plus
`sts:GetCallerIdentity`. The recipe does NOT create the ECR repository
itself.

Pin pattern follows the terraform recipes (PR #241 / #242): the OIDC
role ARN can be passed either as a string input (`deploy-role-arn`,
preferred for cross-owner) or via a secret (`deploy-role-arn-secret`,
fallback). Identifiers are not credentials.

Inputs (highlights):

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string (required) | — | GH Environment gate + job-name suffix. |
| `ecr-repository` | string (required) | — | ECR repo name (without registry prefix). |
| `aws-region` | string | `us-east-1` | |
| `dockerfile-path` | string | `Dockerfile` | |
| `context-path` | string | `.` | |
| `platforms` | string | `linux/arm64` | Comma-separated. |
| `image-tags-input` | string | `latest,__GITHUB_SHA_SHORT__` | `__GITHUB_SHA_SHORT__` placeholder gets expanded. |
| `cache-scope` | string | `container-dev` | GHA `cache-from type=gha,scope=...` scope. |
| `provenance` | bool | `true` | SLSA Build Level 3 provenance attestation. |
| `sbom` | bool | `true` | SPDX SBOM attestation. |
| `cosign-sign` | bool | `false` | Sigstore keyless signing via Fulcio. |
| `deploy-role-arn` | string | `''` | Preferred over secret. |
| `deploy-role-arn-secret` | string | `AWS_DEPLOY_ROLE_ARN` | Fallback secret name. |

Required secrets: `AWS_DEPLOY_ROLE_ARN` (passed explicitly; cross-owner
inheritance blocked by GitHub).

Outputs:

| Output | Notes |
|---|---|
| `image-uri` | `<registry>/<repo>@sha256:...` — what you feed to `reusable-ecs-deploy.yml`. |
| `image-digest` | Bare `sha256:...` (manifest index on multi-platform builds). |
| `image-tags` | Every fully-qualified tag pushed, comma-separated. |
| `registry` | `<account-id>.dkr.ecr.<region>.amazonaws.com`, resolved from the OIDC identity. |

`image-uri` is pinned by **digest**, not tag, on purpose. A downstream
deploy job resolves whatever reference it is given at *its* run time, so
handing it `:latest` would let it land on a different image than the one
this run built. The digest cannot drift. If `docker/build-push-action`
returns no digest the recipe falls back to the first tag and emits a
`::warning::` rather than failing — by that point the image is already in
ECR, and failing a push that succeeded helps nobody.

Chaining the two recipes is the whole point:

```yaml
jobs:
  push:
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-container-deploy-ecr.yml@main
    with: { environment-name: dev, ecr-repository: my-repo, deploy-role-arn: ... }
  roll:
    needs: push
    uses: spark-match/spark-match-01-devops/.github/workflows/reusable-ecs-deploy.yml@main
    with:
      environment-name: dev
      cluster-name: my-cluster
      service-name: my-service
      container-name: agent
      image-uri: ${{ needs.push.outputs.image-uri }}
      deploy-role-arn: ...
```

#### `reusable-ecs-deploy.yml`

Roll an ECS service onto an image that is **already** in ECR: registers a
new task definition revision pointing at the image and updates the
service. Pairs with `reusable-container-deploy-ecr.yml` — that recipe
builds and pushes, this one puts the result in front of traffic. Neither
creates infrastructure; the cluster, service, task definition family and
ALB come from `spark-match-02-infrastructure` (`modules/agent-service`).

The recipe reads the task definition the service is running **right now**
instead of a file in the caller repo. That is deliberate:
`modules/agent-service` declares `lifecycle { ignore_changes =
[task_definition] }` on the service precisely so this pipeline owns the
active revision, and rendering on top of the live one preserves every
field Terraform set (execution role, ARM64 runtime platform, env vars,
log configuration) while changing only the image. The read-only fields
that `DescribeTaskDefinition` returns and `RegisterTaskDefinition`
rejects are stripped with `jq` before rendering.

**The flip side, and it is easy to get caught by**: what this preserves is
whatever Terraform had put on the revision *the service is running*. It does not
pick up later Terraform changes. Because the service ignores `task_definition`,
a `terraform apply` that edits the task definition registers a **new revision
that nothing ever points at**, and this recipe keeps rendering on top of the old
one, so the change never reaches a container. Nothing fails: the apply succeeds,
the deploy succeeds, and the new setting is simply absent.

After a `terraform apply` that changes the task definition, point the service at
the new revision once, by hand:

```bash
aws ecs describe-task-definition --task-definition <family> \
  --query 'taskDefinition.revision' --output text     # -> N

aws ecs update-service --cluster <cluster> --service <service> \
  --task-definition <family>:N --force-new-deployment
```

From then on this recipe starts from the right revision again. A Terraform-made
revision references the image by tag, not by digest, so that manual step drops
the digest pin until the next deploy through this recipe restores it.

`wait-for-service-stability` defaults to `true` so a deploy whose tasks
crash-loop fails the job instead of reporting green.

The OIDC role needs `ecs:DescribeServices`, `ecs:DescribeTaskDefinition`,
`ecs:RegisterTaskDefinition`, `ecs:UpdateService`, `ecs:DescribeTasks`,
`ecs:ListTasks`, `ecs:TagResource`, `iam:PassRole` (execution + task
role) and `sts:GetCallerIdentity`.

Inputs (highlights):

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string (required) | — | GH Environment gate + job-name suffix. |
| `cluster-name` | string (required) | — | Terraform output `agent_cluster_name`. |
| `service-name` | string (required) | — | Terraform output `agent_service_name`. |
| `container-name` | string (required) | — | Terraform output `agent_container_name`. |
| `image-uri` | string (required) | — | Full URI incl. tag or digest; normally the output of a preceding ECR push job. |
| `aws-region` | string | `us-east-1` | |
| `task-definition-family` | string | `''` | Empty resolves the live revision (what you want for a rolling deploy). |
| `wait-for-service-stability` | bool | `true` | |
| `wait-for-minutes` | number | `10` | |
| `force-new-deployment` | bool | `false` | Restart the service without changing the image. |
| `deploy-role-arn` | string | `''` | Preferred over secret. |
| `deploy-role-arn-secret` | string | `AWS_DEPLOY_ROLE_ARN` | Fallback secret name. |

Outputs: `task-definition-arn` (the revision that was registered and
deployed) and `service-url` (ECS console link).

Required secrets: `AWS_DEPLOY_ROLE_ARN` (passed explicitly; cross-owner
inheritance blocked by GitHub).

Caller permissions: `id-token: write` and `contents: read` are mandatory;
`pull-requests: write` only matters if the caller runs this on a
`pull_request` event and wants the failure comment.

#### `reusable-frontend-deploy.yml`

Builds a static frontend and publishes it to S3 behind CloudFront: npm install,
run the caller's build script, `s3 sync` the output, then invalidate the
distribution. Used by `spark-match-04-frontend` for both its real deploy and its
dry-run workflow. It does not create the bucket or the distribution; those come
from `spark-match-02-infrastructure` (`modules/frontend-hosting`).

`role-arn`, `bucket-name` and `distribution-id` are the only three that must be
supplied — the recipe validates them up front via the `validate-workflow-inputs`
composite action and fails with a clear message rather than part-way through a
deploy. Note that they are declared without defaults but are **not** marked
`required`, so the guard is that validation step, not GitHub.

| Input | Type | Default | Notes |
|---|---|---|---|
| `role-arn` | string | `''` | **Must be set.** OIDC role to assume. Pass via `vars`, not `secrets`: an ARN is an identifier. Validated against an ARN regex. |
| `bucket-name` | string | `''` | **Must be set.** Destination S3 bucket. Validated against S3 naming rules. |
| `distribution-id` | string | `''` | **Must be set.** CloudFront distribution ID; validated as 10 to 14 uppercase alphanumerics. |
| `environment-name` | string | `dev` | Logged, and appended to the job name. |
| `gh-environment` | string | `''` | GitHub Environment to bind as an approval gate. Empty means no gate. |
| `aws-region` | string | `us-east-1` | |
| `working-directory` | string | `.` | Directory holding the frontend `package.json`. |
| `build-script` | string | `build` | npm script that produces the dist, e.g. `build:ci`. |
| `node-version` | string | `24` | Accepts `24`, `24.0` or `24.0.0`. |
| `source-dir` | string | `dist` | Build output, relative to `working-directory`. |
| `cache-control-hashed` | string | `public, max-age=31536000, immutable` | For content-hashed assets. |
| `cache-control-html` | string | `no-cache, no-store, must-revalidate` | For HTML and anything not hashed. |
| `invalidation-paths` | string | `/*` | Default invalidates everything. |
| `dry-run` | string | `''` | `"true"` validates inputs and builds, then skips the sync and the invalidation. A string, not a bool. |

Output: `url`, the distribution's public CloudFront domain. It is populated even
on a dry run, so a PR preview job can report where the change would land.

Two cache headers rather than one because the two kinds of file need opposite
treatment: hashed assets are immutable and should be cached for a year, while
`index.html` must never be cached or a browser keeps loading the old asset
manifest and the deploy appears not to have happened.

Requires no secrets. The job is named `frontend-deploy-<environment-name>`. That
suffix comes from an input, not from the branch, so it is fixed for a given
caller job and the check context can safely be made a required status check.

#### `reusable-migrations-dry-run.yml`

Read-only dry-run of node-pg-migrate migrations against an ephemeral `postgres:<version>` service container. Catches SQL sequence bugs (CHECK constraints, FK violations, idempotency failures) at PR time without touching the real RDS database. Used by `spark-match-03-backend` for every PR (Sprint 2 — see ADR-016).

Inputs (highlights):

| Input | Type | Default | Notes |
|---|---|---|---|
| `environment-name` | string | `dev` | Informational; used in job name + logs. |
| `postgres-version` | string | `17` | Postgres major version for the service container. |
| `migrations-dir` | string | `migrations` | Path to the `*.sql` directory (relative to `working-directory`). |
| `migrations-table` | string | `spark_match_migrations` | node-pg-migrate tracking table. |
| `migrations-schema` | string | `public` | Schema holding the tracking table. |
| `npm-script` | string | `migrate:up` | npm script that applies the migrations. Must use node-pg-migrate. |
| `node-version` | string | `24` | Node.js version for the runner. |
| `working-directory` | string | `.` | Where `npm ci` runs. |
| `timeout-minutes` | number | `10` | Job-level timeout. |

Required secrets: none. Pure CLI check against a throwaway Postgres service container — no AWS, no caller secrets.

### Other files in `.github/workflows/`

These workflows are **not** part of the consumer-facing catalog; they only run on this repo itself:

- `ci.yml` — Pull request-triggered lint & security pass. Calls the catalog's own quality recipes (`reusable-actionlint`, `reusable-gitleaks`, `reusable-yamllint`, `reusable-quality`) against this repository so a broken recipe is caught here before consumers break. The node/deploy recipes (`reusable-eslint`, `reusable-node-test`, `reusable-terraform-plan`, `reusable-terraform-apply`, `reusable-terraform-destroy`) are NOT exercised here because this repo has no Node project or Terraform module to lint; they are validated directly by the consumer repos that invoke them (see `docs/VERSIONING.md` § strategy).
- `codeql-actions.yml` — codeql analysis on GitHub Actions YAML. Runs on push to `main`, on pull requests, and weekly.
- `commitlint.yml` — this repo's caller for `reusable-commitlint.yml`. Runs on every PR + push to `main`. Validates Conventional Commits 1.0.0 against `.commitlintrc.json`.
- `release-please.yml` — this repo's caller for `reusable-release-please.yml`. Cuts a "release PR" on every push to `main`; merging the release PR creates the git tag + GitHub Release. Configured via `.github/release-please-config.json` + `.release-please-manifest.json`.
- `sbom.yml` — cyclonedx sbom attached to GitHub Release. Runs on `release: { types: [published] }`.

All catalog recipes in this folder carry the `reusable-` prefix (e.g. `reusable-terraform-plan.yml`). Anything without the prefix is internal CI/CD for this repo only and is NOT safe to call from a consumer repo. See [`docs/VERSIONING.md`](docs/VERSIONING.md) for the per-environment pinning rules.

The latex reusables (`reusable-latex-build.yml`, `reusable-latex-release.yml`) ARE catalog recipes but belong to the `07-article` repository's toolchain; they are not part of the spark-match catalog's core stack. Same applies to the sonar-cloud wrappers (`reusable-sonar-terraform.yml`, `reusable-sonar-typescript.yml`, `reusable-sonar-python.yml`), which target the sonar-cloud org's Terraform/TypeScript/Python projects; to `reusable-migrations-dry-run.yml`, which validates `spark-match-03-backend`'s SQL migrations against an ephemeral Postgres on every PR; and to `reusable-container-deploy-ecr.yml` + `reusable-ecs-deploy.yml`, which together cover the build/push and the rollout half of the ARM64 container deploy path (currently `spark-match-08-deep-agent`).

## Versioning

See [`docs/VERSIONING.md`](docs/VERSIONING.md). Summary:

- All callers pin `@main` regardless of target environment; the dev/prod distinction lives in the caller's `environment-name` input (GH Environment gate) and per-environment deploy role ARN secret. See `docs/VERSIONING.md` § "Modelo" for the full rationale.
- No SemVer in the short term. Breaking changes are communicated by PR + release notes; consumer repos update their pin as part of their normal cadence.
- All deploy recipes use the **same secret-name convention** (e.g. `AWS_DEPLOY_ROLE_ARN`, `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`) so cross-owner callers can pass them explicitly and bypass the `secrets: inherit` block GitHub applies between different owners.
- The org uses a **single-branch model** (`main`-only) since 2026-Q3. There is no `dev` branch and no promotion step. See [Contributing → Workflow](#workflow) for the PR-driven flow.
- Current catalog: cache-key convention **v4** is the most recent explicit version bump. Since v4 the catalog has grown additively via Sprints A/B/C/D — see [`docs/VERSIONING.md`](docs/VERSIONING.md) for the changelog.

## Cache key convention

All node-consuming recipes (`reusable-eslint.yml`, `reusable-node-test.yml`, `reusable-node-typecheck.yml`, `reusable-node-build.yml`) use the canonical cache key:

```
<os>-node-<nodeVersion>-<pkgmanager>-<env>[-<recipeTag>]-<H>
```

- `os` lowercased (`linux`/`windows`/`macos`).
- `nodeVersion` (e.g. `24`).
- `pkgmanager` (`npm` | `pnpm` | `yarn` | `bun`).
- `env` lowercased (`dev` | `prod` | `ci`).
- `recipeTag` recipe-specific (only `reusable-eslint.yml` uses it, for eslint major isolation).
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

- **Per-recipe keys, not per-workflow**. Each recipe that caches should have its own `cache-suffix` segment (today only `reusable-eslint.yml` uses `recipeTag`; consider adding it to other recipes when rolling a major tool version).
- **Bump cache on tool upgrade, not on lockfile hash alone**. A `node-version` or `eslint-version` bump should produce a new key, not silently re-use the old blob with stale binaries.
- **Watch the `<H>` segment**. `sha256(package-lock.json)` means any change to `package-lock.json` (even unrelated deps) invalidates the cache. That's intentional — we want the cache to mirror the exact deps in use — but be aware that a routine `npm i` that touches the lockfile invalidates everything.
- **If a repo is approaching the 10 GB cap**, the most likely culprit is per-branch or per-PR cache keys leaking. The v4 convention deliberately keeps the key space small (no per-PR segment) to avoid this.

Full rationale, examples, extension guide, and migration notes:
[`docs/CACHE.md`](docs/CACHE.md).

## Operational scripts

The `scripts/` directory holds **2 idempotent bash bootstrappers**. Scripts require `gh` CLI authenticated with org admin, support `--dry-run`, and respect `ORG=...` overrides.

| Script | Type | Purpose | Required by a workflow? |
|---|---|---|---|
| [`audit-codeowners-ruleset.sh`](scripts/audit-codeowners-ruleset.sh) | Bash | Audits the ruleset for a given repo against the expected CODE_OWNERS enforcement contract: `require_code_owner_review: true`, `required_approving_review_count >= 1`, `strict_required_status_checks_policy: true`, and a `bypass_actors` inventory. Used to detect drift after the ruleset is edited via the GitHub UI (no YAML schema field for it). | No (manual + CI-friendly) |
| [`configure-repo-rulesets.sh`](scripts/configure-repo-rulesets.sh) | Bash | Declarative reconciler. Reads `governance/repository-governance.json` and reconciles each repo's ruleset to the desired state. Supports `--check`, `--apply`, `--dry-run`, `--repos`, `--strict`, `--prune-unexpected`, `--json`. Backs up the current ruleset before any `PUT` and never uses `DELETE` unless `--prune-unexpected` is passed. | No |

See [`scripts/README.md`](scripts/README.md) for per-script usage, full flag list, and the convention for adding new entries.

## Governance

The `spark-match` org uses **declarative governance**: the desired state lives in [`governance/repository-governance.json`](governance/repository-governance.json), validated against a JSON Schema in [`governance/repository-governance.schema.json`](governance/repository-governance.schema.json) (validated by `.github/workflows/reusable-quality.yml` on every PR). The reconciler (`scripts/configure-repo-rulesets.sh`) brings each repo's actual state in line with the manifest.

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

The repo ships with **bats tests** that run on every PR via `.github/workflows/reusable-quality.yml` and can be executed locally before pushing:

| Suite | Count | File | What it covers |
|---|---|---|---|
| bats — composite actions | 24 | `tests/bats/composite-validate.bats` | Input validation (REQUIRED / ENUM / PATTERN) |
| bats — reconciler | 52 | `tests/bats/reconciler-{prereqs,payload,check,apply,edge-cases}.bats` | Arg parsing, manifest validation, payload construction (jq), `--check` mode, `--apply` mode with PUT/POST/backup/dry-run, edge cases (team-id cache, CRLF, `--org` override) |
| bats — release-please | 16 | `tests/bats/release-please-config.bats` | `.github/release-please-config.json` (PR title pattern, header/footer, changelog sections, schema validation, version pin) |
| bats — workflow hygiene | 12 | `tests/bats/cleanup-batch-pr8.bats` | defaults.run.shell: bash on every workflow; terraform-destroy permissions; environment-name input alias; no `shell: bash` inside workflow_call.inputs |

Shared helpers: `tests/bats/helpers/common.bash` (stubs for `uv` + `pytest`, sets `ACTION_DIR`); `tests/bats/helpers/reconciler.bash` (`gh` stub dispatching on URL + HTTP method, with `json_output` helper for JSON assertions).

### Local setup

```bash
# bats 1.11.1 (one-time install; CI uses the same version):
curl -fsSL https://github.com/bats-core/bats-core/archive/refs/tags/v1.11.1.tar.gz | tar -xz -C /tmp
sudo /tmp/bats-core-1.11.1/install.sh /usr/local
bats --version

# Optional: jq (bats helpers reference it for VALUE parsing):
# Windows: choco install jq
# macOS:   brew install jq
# Linux:   apt-get install jq
```

### Running locally

```bash
# All tests:
bats tests/bats/

# Just one suite:
bats tests/bats/composite-validate.bats
```

Expected runtime: < 1 s for bats. CI adds setup overhead (~25 s total per job including bats download).

### Adding a new test

- For a new bash primitive / composite action → add `tests/bats/<subject>.bats`. Reuse `tests/bats/helpers/common.bash` for `ACTION_DIR` and stub definitions.
- For a new bash script (e.g. a new reconciler / bootstrapper) → add `tests/bats/reconciler-<aspect>.bats` and reuse `tests/bats/helpers/reconciler.bash` for the `gh` stub.

The CI workflow auto-discovers `tests/bats/*.bats`, so no other configuration is needed.

## Contributing

The org uses a **single-branch model** (`main`-only) since 2026-Q3. All changes target `main` directly via pull request; there is no `dev` branch and no promotion step. The ruleset enforces 1 CODE OWNERS approval plus the strict status check list, so every PR runs the full CI matrix before merge.

### Workflow

1. Branch from `main` with a Conventional Commits scope (`chore(cookbook): ...`, `feat(node): ...`, `fix(deploy): ...`, `test(composite): ...`, etc.).
2. Open a pull request against `main`. Code owners are requested automatically via `.github/CODEOWNERS` (rule `require_code_owner_review: true`).
3. Wait for `ci.yml` (actionlint + gitleaks + yamllint + quality) to be green and at least one CODE OWNER approval.
4. Merge with `gh pr merge --squash --admin --delete-branch`. The ruleset deletes the branch on merge automatically.
5. **Self-approval is impossible** even when you are the only CODE OWNER. If you are the sole reviewer, ask another team member or use the admin-bypass dance below.

### Admin bypass (rare; use sparingly)

The ruleset blocks direct pushes to `main` for everyone, including org admins, because `bypass_mode: "pull_request"` only covers the PR context. The escape hatch, for emergency hotfixes and CODE OWNERS migrations:

1. Temporarily flip the ruleset's `bypass_actors[0].bypass_mode` to `"always"`.
2. Direct push to `main`.
3. Restore `bypass_mode: "pull_request"`.
4. Verify with `./scripts/configure-repo-rulesets.sh --check`.

This used to be a **dual**-disable, where step 2 deleted the legacy branch protection's `enforce_admins` flag and the restore put it back to `true` as its "canonical state". That is no longer correct: branch protection here is rulesets plus CODEOWNERS and nothing else, so a repository that still runs a classic layer has debt to remove rather than a flag to toggle. Restoring it would recreate exactly the problem described in `docs/GOVERNANCE-STANDARD.md` § 2.1.

A direct push still blocked after flipping `bypass_mode` is the symptom of a leftover classic layer. Remove it instead of working around it:

```bash
./scripts/configure-repo-rulesets.sh --apply --repos <repo> --prune-legacy-protection
```

The whole window must be < 5 seconds in production. Document the procedure (per repo, never in this public repo) and never use it for ordinary PR work. CODE OWNERS review applies even when `bypass_mode: "always"` if the author is itself a CODE OWNER — in that case, push from a non-CODE-OWNER account or temporarily add the path as `* @devops`.

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
| **actionlint** | Actions YAML syntax | every PR + push | required check | `.github/workflows/reusable-actionlint.yml` |
| **yamllint** | YAML style + parse | every PR + push | required check | `.github/workflows/reusable-yamllint.yml` |
| **gitleaks** | secret scan over git history | every PR + push | required check (org-scoped) | `.github/workflows/reusable-gitleaks.yml` |
| **codeql** | `actions/*` rules (code-injection, unpinned-tag, envvar-injection) | every PR + push + weekly | informational | `.github/workflows/codeql-actions.yml` |
| **Dependabot** | weekly bump PRs for GitHub Actions | Mon 06:00 UTC | enabled | `.github/dependabot.yml` |
| **Dependabot security updates** | auto-PR for known-vulnerable dependencies | on alert | enabled | repo-level (set via `PATCH .../dependabot_security_updates`) |
| **Secret scanning** | native GH secret detection (~200 partner patterns) | always | **enabled** (free, public repo) | repo Settings -> Code security and analysis |
| **Push protection** | block pushes that contain detected secrets | always | **enabled** (free, public repo) | repo Settings -> Code security and analysis |

### codeql posture (snapshot 2026-07-29)

After Sprint A + B + C (PRs #148-#157):

| Rule | Alerts opened | Alerts fixed |
|---|---|---|
| `actions/unpinned-tag` | 71 | 71 (SHA-pinning) |
| `actions/code-injection/medium` | 410 | 410 (env-isolation) |
| `actions/envvar-injection/medium` | 6 | 6 (newline strip + `$GITHUB_ENV` write pattern) |
| **Total** | **502** | **502 (100%)** |

### Secret scanning: current state (enabled 2026-08-04)

`spark-match` is on **GitHub Free**, and this repo is **public**.
GitHub makes native secret scanning and push protection free for
public repositories, so both are enabled at the repo level
(`security_and_analysis`):

- `secret_scanning`: **enabled** — detects ~200 partner token formats
  (GitHub PATs, Slack tokens, Stripe keys, AWS keys, etc.).
- `secret_scanning_push_protection`: **enabled** — blocks a `git push`
  that contains a detected secret before it lands on the remote.

Two sub-features remain **GitHub Advanced Security-only**, confirmed
by a live `PATCH` attempt on 2026-08-04 that returned HTTP 200 but
silently left both `disabled` (no purchase, no error — GitHub just
ignores the field for a repo without a GHAS license):

- `secret_scanning_non_provider_patterns` (generic/heuristic secret
  detection beyond the partner list).
- `secret_scanning_validity_checks` (calls the credential issuer to
  confirm a detected secret is still active).

`reusable-gitleaks.yml` stays in the catalog as defense-in-depth
regardless: it runs on every PR + push over the full git history and
covers the custom AWS patterns (`aws-account-id`, `aws-role-arn`,
`aws-sts-session-token`) that are not part of GitHub's default
partner set.

If you find a leaked secret in git history:

1. **Rotate the secret immediately** (do not wait for a PR).
2. Open a private Security Advisory (see [SECURITY.md](SECURITY.md)).
3. The team will coordinate history rewriting (`git filter-repo`) and
   key rotation across all consumers.

### If this repo (or a consumer) goes private

The free tier above only applies to **public** repositories. A
private repo needs **GitHub Advanced Security** (paid, per active
committer) to unlock any of the four `security_and_analysis` toggles —
including the two (`secret_scanning`, `secret_scanning_push_protection`)
that are free here. To enable all four after a GHAS purchase:

```bash
gh api -X PATCH /repos/<owner>/<repo> --input enable-ghas.json
```

`enable-ghas.json`:

```json
{
  "security_and_analysis": {
    "secret_scanning": {"status": "enabled"},
    "secret_scanning_push_protection": {"status": "enabled"},
    "secret_scanning_non_provider_patterns": {"status": "enabled"},
    "secret_scanning_validity_checks": {"status": "enabled"}
  }
}
```

Keep `reusable-gitleaks.yml` regardless (recommended): it is the only
scanner that understands the org's custom AWS patterns.

## License

GNU General Public License v3.0 or later ([`LICENSE`](LICENSE)). All source files carry SPDX-License-Identifier headers (`GPL-3.0-or-later`). Copyleft: derivative works must also be GPL-3.0+ when distributed.

Prior to 2026-07-26 this repo was Apache-2.0. The change was driven by the catalog's role as infrastructure that other `spark-match/*` repos consume: copyleft ensures the recipes stay free and that improvements flow back to the community. See [CHANGELOG.md](CHANGELOG.md) for the migration entry.

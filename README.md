# Spark Match DevOps — Reusable Workflows

Central repository of CI/CD pipelines for all Spark Match projects. This repo hosts the **GitHub Actions reusable workflows** that consumer projects call. The pattern is one source of truth for shared automation and many thin callers that just dispatch to it, which keeps pipelines identical across projects and concentrates maintenance in a single place.

The catalog has three layers, defined by what they inspect or mutate:

- **ecosystem** — checks that read code only (no caller secrets required)
- **node** — checks for Node workspaces (no caller secrets required)
- **deploy** — deployers that take an OIDC role via caller-scoped secrets

Every recipe accepts an `environment-name` input. It is informational in ecosystem and node recipes (used in job name and step logs), and gates the job on a GitHub Environment in deploy recipes (caller must define the environment and put the role secret there).

## Catalog

The recipes live at the top level of `.github/workflows/`. GitHub Actions requires reusable workflows at the top level, so the three layers above are encoded by naming and ordering rather than by subdirectory.

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
    uses: spark-match/spark-match-01-devops/.github/workflows/actionlint.yml@dev
    with:
      environment-name: ci
```

#### `gitleaks.yml`

Runs secret scanning against the full git history. Pinned to `gitleaks-action@v3`; for org-scoped repos callers MUST forward the `GITLEAKS_LICENSE` secret (free at gitleaks.io) because GitHub drops `secrets: inherit` across owner boundaries.

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | `dev` | Informational only. |

Usage:

```yaml
jobs:
  gitleaks:
    uses: spark-match/spark-match-01-devops/.github/workflows/gitleaks.yml@dev
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
    uses: spark-match/spark-match-01-devops/.github/workflows/yamllint.yml@dev
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
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-fmt.yml@dev
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
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-validate.yml@dev
    with:
      environment-name: dev
      terraform-version: 1.15.7
```

#### `tflint.yml`

Runs `tflint --recursive` against the caller's Terraform code. Caller must provide a `.tflint.hcl` at the repo root — TFLint reads it per-subdirectory and follows the plugin set declared there.

Pins:

- `terraform-linters/setup-tflint@v6` (bumped from v4 in `orion-infrastructure` PR #13)
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
    uses: spark-match/spark-match-01-devops/.github/workflows/tflint.yml@dev
    with:
      environment-name: dev
```

#### `checkov.yml`

Runs `checkov --directory . --framework terraform --compact` against the caller's Terraform code. Hard-fail mode: callers justify each skip inline with `# checkov:skip=CKV_AWS_XX:reason` next to the offending resource. Pinned to checkov `3.2.415` for reproducible output (per `orion-infrastructure` PR #18).

Discipline (from `orion-infrastructure` PR #18):

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
    uses: spark-match/spark-match-01-devops/.github/workflows/checkov.yml@dev
    with:
      environment-name: dev
```

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
    uses: spark-match/spark-match-01-devops/.github/workflows/eslint.yml@dev
    with:
      environment-name: ci
      eslint-version: 10
      # lint-script defaults to "lint"
```

### python

#### `python-ci.yml`

Runs a Python project's QA pipeline using `uv` for dependency management, then `ruff` + `mypy` + `pytest` for static analysis + tests. Designed for projects that pin Python in `.python-version` and lock via `uv.lock`. The recipe is GENERIC: it does not assume a specific project layout beyond `pyproject.toml` + `uv.lock` in `working-directory`.

Each step is gated by an entry in the CSV `commands` input, so callers can opt into any subset (e.g. skip `mypy` on a legacy codebase, or skip `coverage:upload` if the project doesn't generate coverage). Defaults run the full QA set + upload coverage as an artifact.

Inputs:

| Input        | Type   | Default | Notes |
|--------------|--------|---------|-------|
| environment-name | string | — (required) | Used as job name + optional GH Environment gate. |
| python-versions | string | `"3.12"` | JSON list, fed into the matrix via `fromJSON()`. Use `'"3.11","3.12"'` for multi-version. |
| working-directory | string | `.` | Where `pyproject.toml` + `uv.lock` live. |
| commands | string | `lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest,coverage:upload` | CSV; valid steps: `lint:ruff-format`, `lint:ruff-check`, `typecheck:mypy`, `test:pytest`, `coverage:upload`, `none` (manual-mode only). |
| dependency-groups | string | `dev` | Passed to `uv sync --group` (space-separated). Use `dev bedrock` to also enable a `bedrock` group. |
| ruff-targets | string | `src tests` | CSV of paths for `ruff format/check`. |
| mypy-targets | string | `src` | CSV of paths for `mypy`. |
| pytest-targets | string | `tests` | Path for `pytest`. |
| coverage-output | string | `coverage.xml` | Artifact path uploaded (when `coverage:upload` is in `commands`). |
| setup-uv-version | string | `latest` | uv version pinned via `astral-sh/setup-uv@v6`. |

Required secrets: none (ecosystem-style, no AWS).

Usage (typical orion-cognitive-agent layout — both `dev` and `bedrock` groups):

```yaml
jobs:
  python-ci:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@dev
    with:
      environment-name: ci
      python-versions: '"3.12"'
      working-directory: '.'
      dependency-groups: 'dev bedrock'
      commands: lint:ruff-format,lint:ruff-check,typecheck:mypy,test:pytest,coverage:upload
```

Usage (multi-version matrix):

```yaml
jobs:
  python-ci:
    uses: spark-match/spark-match-01-devops/.github/workflows/python-ci.yml@dev
    with:
      environment-name: ci
      python-versions: '"3.11","3.12"'
```

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
    uses: spark-match/spark-match-01-devops/.github/workflows/sam-deploy.yml@dev
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
    uses: spark-match/spark-match-01-devops/.github/workflows/container-deploy-ecr.yml@dev
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

### Other files in `.github/workflows/`

These are not consumed by other Spark Match repos but are kept here for this repo's own CI:

- `ci.yml` — Pull request-triggered self-test. Calls the three pure-lint ecosystem recipes (`actionlint`, `gitleaks`, `yamllint`) against this repository so a broken recipe is caught here before consumers break. The four terraform ecosystem recipes (`terraform-fmt`, `terraform-validate`, `tflint`, `checkov`) are NOT exercised here because this repo has no Terraform code to lint; they are validated by consumer repos like `orion-infrastructure`.
- `codeql.yml` — CodeQL analysis on GitHub Actions YAML. Runs on push to `main` / `dev`, on pull requests, and weekly.

The LaTeX reusables (`latex-build.yml`, `latex-release.yml`) belong to the `07-article` repository's toolchain and are not part of the orion stack.

## Versioning

See [`docs/VERSIONING.md`](docs/VERSIONING.md). Summary:

- The catalog can be pinned by environment (`@dev` for dev callers, `@main` for prod callers) — changes are tested against dev deploys before they reach prod. The canonical consumer `orion-infrastructure` currently pins both envs to `@main` (single-tier strategy); teams that maintain a `dev` environment downstream of `main` can adopt the dual-pin strategy.
- No SemVer in the short term. Breaking changes are communicated by PR + release notes.
- All deploy recipes use the **same secret-name convention** (e.g. `AWS_DEPLOY_ROLE_ARN`, `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`) so cross-owner callers can pass them explicitly and bypass the `secrets: inherit` block GitHub applies between different owners.

## Repository layout

```
spark-match-01-devops/
  .github/
    CODEOWNERS                  Approval policy (devops + product-owners)
    dependabot.yml              Weekly GitHub Actions bump PRs
      workflows/
        ci.yml                    Self-test PR wrapper
        actionlint.yml            ecosystem
        gitleaks.yml              ecosystem
        yamllint.yml              ecosystem
        terraform-fmt.yml         ecosystem
        terraform-validate.yml    ecosystem
        tflint.yml                ecosystem
        checkov.yml               ecosystem
        eslint.yml                node
        sam-deploy.yml            deploy
        terraform-plan.yml        deploy
        terraform-apply.yml       deploy
        angular-spa-deploy.yml    deploy (Angular SPA -> S3 + CloudFront)
        codeql.yml                self (security)
        latex-build.yml           article-side
        latex-release.yml         article-side
  docs/
    VERSIONING.md               Pin-by-env rules and conventions
  scripts/
    README.md                   Operational scripts (configure-merge-methods, etc.)
    *.sh / *.ps1                Idempotent, --dry-run supported; require `gh` admin auth
  LICENSE                       Apache-2.0
  README.md                     This file
  .yamllint.yml                 Lint config for non-workflow YAML
  .gitignore                    IDE / OS / Terraform artifacts
```

## Operational scripts

The `scripts/` directory holds idempotent operational scripts that apply org-wide policy (for example `configure-merge-methods.sh` sets squash-only on all repos in the org). All scripts require `gh` CLI authenticated with org admin, support `--dry-run`, and respect `ORG=...` overrides. See [`scripts/README.md`](scripts/README.md).

## Contributing

Changes to the catalog follow the git workflow in this repo:

1. Branch from `dev` with a Conventional Commits scope (`chore(cookbook): ...`, `feat(node): ...`, `fix(deploy): ...`).
2. Open a pull request against `dev`.
3. Code owners review (see `.github/CODEOWNERS`).
4. After `ci.yml` self-test is green and at least one external caller (for example `orion-backend`) has validated the change in `dev`, the PR is promoted `dev` to `main` by a second PR.
5. Branch is deleted on merge (ruleset policy).

When adding a new recipe:

- Place the file at the top level of `.github/workflows/`. Subfolders break `uses: ./...`.
- Re-declare `permissions` for whatever the recipe needs (`contents: read`, `id-token: write`, etc.).
- For deploy recipes, declare secrets by explicit name and follow the same-name convention used by existing deploy recipes.
- Update `docs/VERSIONING.md` if the recipe introduces a new convention.

When bumping external tool versions:

- Pin `actionlint` to a release tag (never `main`).
- Pin `yamllint` to `1.35.1` unless the team agrees to migrate to the v2 rewrites.
- Use Dependabot (`.github/dependabot.yml`) for routine bumps; do pin by hand when changing the version the recipe defaults to.

## License

Apache-2.0. See [`LICENSE`](LICENSE).

# caller-minimal — minimal caller examples

A self-contained set of minimal-but-realistic caller workflows, one per
catalog layer. Each subdirectory is shaped like a tiny caller repo: it
has its own `.github/workflows/*.yml` and a short README explaining what
the workflow demonstrates, the inputs it sets explicitly, and the
gotchas that apply.

## Index

| Subdirectory | Layer | Workflow(s) called |
|---|---|---|
| [`python-ci/`](python-ci/) | python | `python-ci.yml` |
| [`node-ci/`](node-ci/) | node + ecosystem | `eslint.yml` + `node-test.yml` + `node-build.yml` + `gitleaks.yml` |
| [`terraform-ci/`](terraform-ci/) | ecosystem + deploy | `terraform-fmt.yml` + `terraform-validate.yml` + `tflint.yml` + `terraform-plan.yml` |
| [`sam-deploy/`](sam-deploy/) | ecosystem + deploy | `cfn-nag.yml` + `lambda-permission-source-arn.yml` + `sam-deploy.yml` |

## How to use

Each subdirectory is a copy-paste fragment, not a runnable repo on its
own. To turn one into a live CI:

1. Create a new repo (or copy into an existing one).
2. Drop the subdirectory's `.github/workflows/<workflow>.yml` into the
   new repo's `.github/workflows/`.
3. Add the secrets the workflow expects (see each subdirectory's
   `README.md` for the list).
4. Push. The first run will materialize the workflow.

## Conventions used across all examples

- **Pin `@main`**, never a SHA or branch. This matches the catalog's
  pinning rule per `docs/VERSIONING.md`.
- **Re-declare `permissions:` at the workflow level** (never `write-all`
  — minimum-scope per the security baseline).
- **For deploy recipes, declare secrets by explicit name** using the
  same-name convention (`AWS_DEPLOY_ROLE_ARN`, `AWS_PLAN_ROLE_ARN`,
  `AWS_APPLY_ROLE_ARN`). This is required for cross-owner callers.
- **OIDC requires `id-token: write`** at the workflow or job level.
- **GitHub Environments gate deploy jobs.** Set up the env in the
  caller repo's Settings > Environments before invoking deploy recipes.
- **`environment-name` matches the env name** for deploy recipes, or is
  `ci` (default) for ecosystem/node/python recipes.

## What this directory does NOT cover

- Real OIDC role ARNs or AWS account numbers — every example uses
  placeholders (`<AWS_ACCOUNT_ID>`).
- GitHub App authentication (PATs, install tokens) — the catalog uses
  `secrets.GITHUB_TOKEN` via cross-repo `uses:`.
- Multi-stack monorepo layouts — examples assume the workflow lives in
  the repo it lints/deploys. Subdirectory-relative `working-directory`
  input is set per recipe in the catalog.
- Composite-action callers — the catalog ships 2 composite actions
  (`validate-workflow-inputs`, `run-pytest-with-args`); both are used
  internally by `quality.yml`. The examples focus on the workflow
  surface because that's what consumer repos actually `uses:`.

## Adding a new example

1. Pick a layer not yet covered, or a recipe in an existing layer that
   you think is under-documented.
2. Create `caller-minimal/<name>/` with `README.md` + `.github/workflows/*.yml`.
3. The workflow MUST include:
   - `permissions:` (minimum, never `write-all`)
   - The `uses:` line with `@main`
   - `environment-name` input
   - For deploy recipes: `id-token: write` + the deploy-role secret
4. Add a row to the table above.
5. Open a PR.

# sam-deploy

Demonstrates a minimal caller for the AWS SAM deploy pipeline:
`cfn-nag.yml` + `lambda-permission-source-arn.yml` + `sam-deploy.yml`.
This is the canonical setup for a serverless backend repo.

## What this example covers

- 3 reusables, with the SAM static-analysis jobs running first and the
  deploy job gated on their success.
- `id-token: write` at the workflow level (OIDC for AWS).
- `AWS_DEPLOY_ROLE_ARN` secret passed explicitly (same-name
  convention).
- `environment-name: dev` — gates the deploy job on a GitHub
  Environment (caller must define the env in Settings > Environments).

## What you must change to make it yours

1. **`aws-region`** — defaults to `us-east-1`; set per your stack.
2. **`stack-name`** — your CloudFormation stack name.
3. **`sam-template`** — defaults to `template.yaml`.
4. **`sam-config-env`** — defaults to `environment-name`. Set
   explicitly if your `samconfig.toml` uses a different section name.
5. **`s3-bucket`** — your SAM artifacts bucket.
6. **Layers build script** — defaults to `layer:build:all`; change if
   your `package.json` uses different names.

## Required secrets

`AWS_DEPLOY_ROLE_ARN` — IAM role with permissions for CloudFormation,
IAM, S3, SSM, and Lambda publish. Trust policy for
`token.actions.githubusercontent.com`, scoped to the caller's `sub`
(e.g. `repo:spark-match/*:ref:refs/heads/main`).

## Permissions matrix

This caller workflow grants:

- `contents: read` — checkout the repo
- `id-token: write` — OIDC for AWS
- `pull-requests: read` — for the lambda-permission-source-arn job to
  post PR comments (optional)

The `sam-deploy.yml` job requests additional permissions as needed
(scoped to the deploy job, not the caller workflow).

## Expected run time

- `cfn-nag`: ~30 s (Ruby + cfn-nag scan)
- `lambda-permission-source-arn`: ~5 s (Python scan)
- `sam-deploy`: ~3-5 min (npm ci + Layers build + `sam build` + `sam
  deploy --no-confirm-changeset`)

Total wall time: ~5-6 min.

## Where to look in this repo

- `README.md` § Catalog → sam-deploy — full recipe description.
- `scripts/check_lambda_permission_source_arn.py` — the SAM guard
  script that powers `lambda-permission-source-arn.yml`.
- `tests/python/test_lambda.py` — the pytest suite that verifies the
  guard's logic.

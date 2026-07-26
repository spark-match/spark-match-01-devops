# terraform-ci

Demonstrates a minimal caller for the Terraform pipeline: `fmt` ->
`validate` -> `tflint` -> `plan`. Drops `checkov` (kept for callers
that want the extra coverage) and `apply`/`destroy` (kept for
deploy-stage workflows).

## What this example covers

- 4 reusables in a layered DAG: `fmt -> validate -> tflint -> plan`.
- `terraform-version: '1.10.0'` pinned (the catalog's default at the
  time of writing; bump per your project's Terraform requirement).
- `working-directory: live/dev` — a common pattern for monorepos
  where Terraform code lives under `live/<env>/` and modules under
  `modules/`. Adjust per your layout.
- `plan-role-arn-secret: AWS_PLAN_ROLE_ARN` — uses the same-name
  convention so cross-owner callers work without renaming.
- `concurrency: cancel-in-progress: true` so rapid pushes don't pile
  up plan runs against the same backend.

## What you must change to make it yours

1. **`working-directory`** — point at the directory containing
   `versions.tf` + `main.tf`.
2. **`terraform-version`** — pin to the version your `.terraform-version`
   file declares.
3. **`backend-bucket`, `backend-key`, `tfvars-file`** for `terraform-plan.yml`.
4. **`aws-region`** — defaults to `us-east-1`.
5. **Add `checkov`** if you want SCA on Terraform code (set
   `checkov-version` to pin).

## Required secrets

`AWS_PLAN_ROLE_ARN` — IAM role with `terraform plan` permission, trust
policy for `token.actions.githubusercontent.com`, scoped to the
caller's `sub` (e.g. `repo:spark-match/*:ref:refs/heads/main`).

Same-name convention: the recipe reads `secrets: AWS_PLAN_ROLE_ARN` by
default. If you fork the catalog and run from a different org, pass it
explicitly.

## Permissions matrix

This caller workflow grants only `contents: read`. The plan job
requests `id-token: write` for OIDC; the recipe writes to PR comments
and uploads artifacts (both `pull-requests: write` + `contents: write`
scoped to the recipe run, not the caller).

## Expected run time

- `fmt`: ~5 s
- `validate`: ~30-60 s (terraform init for each module)
- `tflint`: ~10 s
- `plan`: ~30-90 s depending on module count

Total wall time: ~2-3 min on a small monorepo.

## Where to look in this repo

- `README.md` § Catalog → terraform-* — recipe descriptions.
- `docs/VERSIONING.md` § "Modelo" — pin-by-environment rule.

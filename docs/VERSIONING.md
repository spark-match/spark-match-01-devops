# Versioning of 01-devops

> **Decision (2026-07)**: we do NOT use SemVer for now.

## Model: single main branch with a caller smoke test

A single `main` branch is the canonical source of every reusable. Callers always
reference `@main`:

- Caller deploying to **dev** → `uses: .../reusable-terraform-apply.yml@main` (same reusable, environment selected via `environment-name`)
- Caller deploying to **prod** → `uses: .../reusable-terraform-apply.yml@main` (same reusable, environment selected via `environment-name`)

The dev/prod distinction lives in:

1. The **`environment-name` input** the caller passes to the recipe (GitHub Environment gate).
2. The **`*_DEPLOY_ROLE_ARN` secret** the caller injects (a different ARN per environment).
3. The **caller workflow** in the consuming repository, which assembles the job with the right env + ARN combination.

## Why this model, rather than pinning per environment

Consolidating on `main` removes the double source of truth the previous model
produced (`dev` to test, `main` for prod):

- **A change is tested against the real caller, not an environment proxy.** The pull request against `main` references the SHA of the recipe about to be merged; the caller runs its tests against that exact SHA before approval.
- **Less drift.** There is no window where `dev` and `main` diverge silently, and no risk of forgetting to promote a fix.
- **One set of rules.** The ruleset plus CODEOWNERS (gradually moving to `required_reviewers` per team; the historical plan lived in an external document that has since been retired) protects the only branch that matters.
- **Trivial rollback.** `git revert` plus a push restores the previous state with no cross-branch coordination.

## Trade-off

- Every pull request against `main` requires **at least one canonical caller** (defined in § "How changes are tested") to validate the change before merge. If that caller is switched off or cannot validate — AWS cost, for instance — the reviewer demands explicit evidence instead (`act` logs, local test output, dry-run output).
- A bad change on `main` reaches **every caller at once**. That is exactly what CODEOWNERS plus a mandatory reviewer is there to mitigate.
- There is no cheap test ring before production. The mitigation is the mandatory smoke test plus a fast cherry-pick if something breaks — there is nothing to re-promote.

## When SemVer would be justified

If at some point we want to publish stable versions of the reusables for third
parties, rather than only the internal spark-match repositories, we would tag
`vX.Y.Z` on `main` after a smoke-test period with the canonical callers. That
would require:

1. A pull request setting up the release process (a GitHub Action that tags automatically, and so on).
2. Migrating callers to a pinned version.
3. Keeping a `CHANGELOG.md` with breaking changes.

Until then, internal callers reference `@main` and rely on the ruleset plus
CODEOWNERS plus a mandatory reviewer.

## Recipe catalog

The authoritative list is the tree itself:

```bash
ls .github/workflows/reusable-*.yml
```

No inventory is transcribed here on purpose. The one that used to sit in this
section listed eighteen recipes against twenty-seven on disk, and named files
that had since been renamed. A catalog copied into prose has to be hand-synced
with a directory that grows most weeks, and when it falls behind it fails
silently — a document has no way to report that it is wrong.

`README.md` carries the documented catalog, and `tests/bats/readme-fidelity.bats`
enforces the correspondence in both directions: every reusable on disk is
documented, and nothing documented is a ghost.

### Why there are no subfolders (a GitHub Actions limitation)

GitHub Actions requires reusable workflows to sit at the **top level** of
`.github/workflows/`. A reference like `uses: ./path/to/subfolder/file.yml`
fails with `invalid value workflow reference: workflows must be defined at the
top level of the .github/workflows/ directory`.

That is why every reusable lives at the same level as `ci.yml`,
`codeql-actions.yml` and the rest. The layer — ecosystem, node, deploy — is
encoded in the `reusable-` prefix plus alphabetical grouping of the filename,
this document, and labels in the job name (`actionlint (env=...)`).

### Input convention

Every recipe accepts at least `environment-name` (informational: logged in the
job name and in step logs). Deploy recipes additionally use it as a **GitHub
Environment gate** — the caller must have an environment with that name and the
`AWS_DEPLOY_ROLE_ARN` / `CFN_ROLE_ARN` secret inside it.

### Catalog rules

- **No internal coupling between layers.** Each recipe is callable on its own. A caller can use `reusable-actionlint.yml` and `reusable-eslint.yml` without taking `reusable-yamllint.yml`.
- **Secrets only in deploy recipes.** Ecosystem and node recipes receive no secrets — they are pure static checks over code.
- **Cross-owner friendly.** Recipes take `secrets:` by explicit name (`AWS_DEPLOY_ROLE_ARN`, for instance) and expect the caller to pass them with `secrets: inherit` or explicitly. This avoids GitHub's block on cross-owner callers, which the legacy pre-rebrand project hit.
- **External tools are pinned.** actionlint v1.7.7, yamllint 1.35.1; eslint, terraform and sam-cli versions are parameterised via input.
- **The `reusable-` prefix is mandatory** on files with `workflow_call`. No prefix means internal CI/CD for this repository, not callable from consumers.

### How changes are tested

1. `ci.yml` runs the ecosystem recipes against this repository on every pull
   request. It catches lint, secret and YAML-format regressions in the catalog
   itself, but does **not** exercise the node or deploy reusables — this
   repository has no Node project and no Terraform to run them against.
2. Each recipe is validated when a caller repository invokes it from its own
   pull request against `main`. Canonical mapping, all callers on `@main`:
   - `reusable-eslint.yml`, `reusable-node-test.yml`: `spark-match-04-frontend`
   - `reusable-terraform-plan.yml`, `reusable-terraform-apply.yml`, and the Terraform ecosystem recipes (`reusable-terraform-validate.yml`, `reusable-tflint.yml`): `spark-match-02-infrastructure`
   - `reusable-latex-build.yml`, `reusable-latex-release.yml`: `spark-match-06-article`
   - `reusable-actionlint.yml`, `reusable-gitleaks.yml`, `reusable-yamllint.yml`: the local `ci.yml` (see point 1)
3. If the pull request changes an input or adds a step to a recipe, the reviewer
   demands an explicit smoke test of the corresponding caller before approving
   the merge. Declaring that evidence in the pull request description is the
   author's responsibility (`act` logs, test output, a capture of the caller
   running against the pull request SHA). This is not automatable cross-owner
   without reintroducing the dependency this architecture removed.

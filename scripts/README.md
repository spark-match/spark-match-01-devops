# scripts/

Operational scripts for the `spark-match` org.

## Catalog

| Script | Purpose | Invocation | Required by a workflow? |
|---|---|---|---|
| [`check_lambda_permission_source_arn.py`](./check_lambda_permission_source_arn.py) | SAM guard: every `AWS::Lambda::Permission` resource in scanned paths must declare `SourceArn:` or `SourceAccount:`. Stdlib-only Python; regex-based; comment-aware. Required because `cfn-nag` 0.8.10 lacks a rule for missing `SourceArn`/`SourceAccount`. | `python3 check_lambda_permission_source_arn.py [scan-paths...]` | **Yes** — consumed by `.github/workflows/lambda-permission-source-arn.yml` (curl from raw @main) |
| [`audit-codeowners-ruleset.sh`](./audit-codeowners-ruleset.sh) | Audits the ruleset for a given repo against the expected CODE_OWNERS enforcement contract: `require_code_owner_review: true`, `required_approving_review_count >= 1`, `strict_required_status_checks_policy: true`, and a `bypass_actors` inventory. Used to detect drift after the ruleset is edited via the GitHub UI (no YAML schema field for it). | `./scripts/audit-codeowners-ruleset.sh`<br>`./scripts/audit-codeowners-ruleset.sh --json` | No (manual + CI-friendly) |
| [`cleanup-merged-branches.sh`](./cleanup-merged-branches.sh) | Deletes local + remote refs whose tip is already merged into `origin/main`. Detects both linear-merged branches (`git merge-base --is-ancestor`) AND squash-merged branches (subject-match against `origin/main`). Safety: refuses to run from any branch other than `main`; excludes `release-please--*`; uses `-d` (safe) for linear and `-D` (forced) only for subject-confirmed squash-merged. | `./scripts/cleanup-merged-branches.sh --dry-run` (preview)<br>`./scripts/cleanup-merged-branches.sh --remote` (also delete remote refs) | No (manual) |
| [`configure-merge-methods.sh`](./configure-merge-methods.sh) | Applies a uniform merge policy across every repo in the org: `allow_squash_merge=true`, `allow_merge_commit=false`, `allow_rebase_merge=false`, `delete_branch_on_merge=true`, `squash_merge_commit_title=PR_TITLE`, `squash_merge_commit_message=PR_BODY`. | `./configure-merge-methods.sh [--dry-run] [--repos r1,r2] [--allow-merge] [--allow-rebase]` | No |
| [`configure-repo-rulesets.sh`](./configure-repo-rulesets.sh) | Declarative reconciler. Reads `../governance/repository-governance.json` and reconciles each repo's ruleset to the desired state via GitHub REST API. Replaces the destructive bootstrap (`POST`-only, no PUT, no backup) with an idempotent reconciler that supports `--check`, `--apply`, `--dry-run`, `--repos`, `--strict`, and `--prune-unexpected`. Resolves team slug → team ID, backs up the current ruleset before any `PUT`, and never uses `DELETE` unless `--prune-unexpected` is passed. | `./configure-repo-rulesets.sh --check --repos spark-match-01-devops`<br>`./configure-repo-rulesets.sh --dry-run --apply --repos spark-match-01-devops`<br>`./configure-repo-rulesets.sh --apply` | No |

## Conventions

- **Idempotent**: running any script twice produces the same result.
- **`--dry-run`**: every script supports this and prints what it would do without applying changes.
- **Environment overrides**: scripts respect overrides (`ORG=...`, `SQUASH_TITLE=...`, etc.).
- **`gh` CLI required**: scripts authenticate via `gh`, which must have admin scope on the org (`admin:org` token scope).

## Running a script

```bash
chmod +x scripts/<script-name>.sh             # only the first time

./scripts/configure-merge-methods.sh --dry-run  # recommended first
./scripts/configure-merge-methods.sh            # apply
```

The Python script is invoked directly:

```bash
python3 scripts/check_lambda_permission_source_arn.py template.yaml contexts/
```

## Adding a new script

1. Create a `.sh` or `.py` file in this directory.
2. Start with a shebang (`#!/usr/bin/env bash` or `#!/usr/bin/env python3`) and `set -euo pipefail` for shell scripts.
3. Document the header with comments explaining purpose, usage, and whether a workflow depends on it.
4. Add a row to the catalog table above.
5. Commit with `feat(scripts): <short description>` or `chore(scripts): ...`.
6. Open a PR with review from `@spark-match/devops` (see `.github/CODEOWNERS`).

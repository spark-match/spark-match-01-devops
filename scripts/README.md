# scripts/

Operational scripts for the `spark-match` org.

## Catalog

| Script | Purpose | Invocation | Required by a workflow? |
|---|---|---|---|
| [`check_lambda_permission_source_arn.py`](./check_lambda_permission_source_arn.py) | SAM guard: every `AWS::Lambda::Permission` resource in scanned paths must declare `SourceArn:` or `SourceAccount:`. Stdlib-only Python; regex-based; comment-aware. Required because `cfn-nag` 0.8.10 lacks a rule for missing `SourceArn`/`SourceAccount`. | `python3 check_lambda_permission_source_arn.py [scan-paths...]` | **Yes** — consumed by `.github/workflows/lambda-permission-source-arn.yml` (curl from raw @main) |
| [`configure-merge-methods.sh`](./configure-merge-methods.sh) | Applies a uniform merge policy across every repo in the org: `allow_squash_merge=true`, `allow_merge_commit=false`, `allow_rebase_merge=false`, `delete_branch_on_merge=true`, `squash_merge_commit_title=PR_TITLE`, `squash_merge_commit_message=PR_BODY`. | `./configure-merge-methods.sh [--dry-run] [--repos r1,r2] [--allow-merge] [--allow-rebase]` | No |
| [`configure-repo-rulesets.sh`](./configure-repo-rulesets.sh) | Creates the `spark-match-default-branch-protection` ruleset per-repo (GitHub Free has no org-level rulesets). Adds `pull_request` (1 approval + code-owner review), `non_fast_forward`, `required_linear_history`, and optional `required_status_checks`. Bypass actor: `OrganizationAdmin` with `bypass_mode: always`. This is the **only** ruleset bootstrap script retained — the stricter `bypass_mode: pull_request` variant was removed because the live ruleset on every primary repo uses `always`, and the stricter script was a footgun (executing it would overwrite the live ruleset). | `./configure-repo-rulesets.sh [--dry-run] [--repos r1,r2] [--status-checks "Plan (dev),Checkov"] [--approvals N] [--delete-existing]` | No |

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

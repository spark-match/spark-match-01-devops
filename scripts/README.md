# scripts/

Operational scripts for the `spark-match` org.

## Catalog

| Script | Purpose | Invocation | Required by a workflow? |
|---|---|---|---|
| [`audit-codeowners-ruleset.sh`](./audit-codeowners-ruleset.sh) | Audits the ruleset for a given repo against the expected CODE_OWNERS enforcement contract: `require_code_owner_review: true`, `required_approving_review_count >= 1`, `strict_required_status_checks_policy: true`, and a `bypass_actors` inventory. Used to detect drift after the ruleset is edited via the GitHub UI (no YAML schema field for it). | `./scripts/audit-codeowners-ruleset.sh`<br>`./scripts/audit-codeowners-ruleset.sh --json` | No (manual + CI-friendly) |
| [`configure-repo-rulesets.sh`](./configure-repo-rulesets.sh) | Declarative reconciler. Reads `../governance/repository-governance.json` and reconciles each repo's ruleset to the desired state via GitHub REST API. Replaces the destructive bootstrap (`POST`-only, no PUT, no backup) with an idempotent reconciler that supports `--check`, `--apply`, `--dry-run`, `--repos`, `--strict`, and `--prune-unexpected`. Resolves team slug → team ID, backs up the current ruleset before any `PUT`, and never uses `DELETE` unless `--prune-unexpected` is passed. | `./configure-repo-rulesets.sh --check --repos spark-match-01-devops`<br>`./configure-repo-rulesets.sh --dry-run --apply --repos spark-match-01-devops`<br>`./configure-repo-rulesets.sh --apply` | No |

## Conventions

- **Idempotent**: running any script twice produces the same result.
- **`--dry-run`**: every script supports this and prints what it would do without applying changes.
- **Environment overrides**: scripts respect overrides (`ORG=...`, `SQUASH_TITLE=...`, etc.).
- **`gh` CLI required**: scripts authenticate via `gh`, which must have admin scope on the org (`admin:org` token scope).

## Running a script

```bash
chmod +x scripts/<script-name>.sh             # only the first time

./scripts/configure-repo-rulesets.sh --check --repos spark-match-01-devops  # recommended first
./scripts/configure-repo-rulesets.sh --dry-run --apply --repos spark-match-01-devops  # apply
```

## Adding a new script

1. Create a `.sh` or `.py` file in this directory.
2. Start with a shebang (`#!/usr/bin/env bash` or `#!/usr/bin/env python3`) and `set -euo pipefail` for shell scripts.
3. Document the header with comments explaining purpose, usage, and whether a workflow depends on it.
4. Add a row to the catalog table above.
5. Commit with `feat(scripts): <short description>` or `chore(scripts): ...`.
6. Open a PR with review from `@spark-match/devops` (see `.github/CODEOWNERS`).

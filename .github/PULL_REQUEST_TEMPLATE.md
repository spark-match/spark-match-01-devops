<!--
PULL_REQUEST_TEMPLATE.md - applied automatically to every new PR targeting main.
Repo convention: see CONTRIBUTING.md § "Pull request workflow". This template
mirrors the structure the maintainers expect; do not delete sections.
-->

## Summary

<!-- One or two paragraphs: what does this PR do, and why. Cross-reference the
     GitHub issue it closes with `Closes #NNN` or `Refs #NNN`. -->

## Type of change

<!-- Pick ONE that matches the conventional-commit subject prefix. -->

- [ ] `feat` — new reusable workflow, composite action, or script (MINOR)
- [ ] `fix` — bug fix in an existing recipe (PATCH)
- [ ] `docs` — README, docs/, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT only
- [ ] `test` — bats or pytest only, no production code change
- [ ] `chore` — maintenance with no production code change (deps, ignore files)
- [ ] `refactor` — code change that neither fixes a bug nor adds a feature
- [ ] `perf` — performance improvement (no behavior change)
- [ ] `ci` — changes to `.github/workflows/` (this repo's own CI only)
- [ ] `quality` — bats/pytest/shellcheck/JSON-Schema infra
- [ ] `reconciler` — `configure-repo-rulesets.sh` only
- [ ] `governance` — `governance/*.json` or ruleset policy

## Scope

<!-- Short label identifying the area touched (used as the CC scope). Examples:
     composite, ecosystem, node, python, deploy, governance, docs, ci, scripts. -->

**Scope**: `{{ scope }}`

## What changed

<!-- Bullet list of the substantive changes. Be specific. For new recipes,
     link to the workflow file or script path. For bug fixes, link to the
     root cause in the existing recipe. -->

- {{ change 1 }}
- {{ change 2 }}

## How to test

<!-- Describe the local steps to reproduce the change and verify it works.
     Reference the suite in tests/bats/ or tests/python/ if applicable. -->

1. {{ step 1 }}
2. {{ step 2 }}
3. Expected: {{ expected outcome }}

## Checklist

<!-- Mandatory items; uncheck any that do not apply and explain in a comment. -->

- [ ] I ran `bats tests/bats/` locally and all tests pass.
- [ ] I ran `python -m pytest tests/python/ -v` locally and all tests pass.
- [ ] I ran `shellcheck scripts/*.sh .github/actions/*/action.sh` with no warnings.
- [ ] I ran `actionlint .github/workflows/*.yml` with no errors.
- [ ] If I changed a recipe, I added or updated tests in `tests/bats/` or `tests/python/`.
- [ ] If I added a new top-level path, I noted it in the PR body for the CODEOWNERS follow-up.
- [ ] I followed the branch-naming convention (`<type>/<scope>-<short-desc>`).
- [ ] My commit subject follows Conventional Commits 1.0.0.
- [ ] I am NOT the sole CODE OWNER of the paths I changed (self-approval is impossible).

## Risk and rollout

<!-- Mandatory for any `feat`, `fix`, `chore(deps)`, or `perf` change. Skip for
     `docs`, `test`, or `quality`. -->

- **Backward compatibility**: <!-- yes/no, why -->
- **Caller impact**: <!-- which consumer repos will pick this up via @main pin; expected behavior on next CI run -->
- **Rollback plan**: <!-- how to revert if a consumer breaks; typically `git revert` of this PR since callers pin @main -->

## Refs

<!-- Cross-references: issues, related PRs, upstream docs. -->

- Closes #
- Refs #
- Upstream docs: {{ link }}
- Related PR: #{{ N }}

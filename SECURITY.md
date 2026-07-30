# Security Policy

## Scope

This repository (`spark-match/spark-match-01-devops`) ships:

- **Reusable GitHub Actions workflows** consumed by every other `spark-match/*` repository (lint, Terraform, SAM, deploy, etc.).
- **Composite actions** (`validate-workflow-inputs`, `run-pytest-with-args`) used inside those workflows.
- **Operational scripts** (`configure-repo-rulesets.sh`, `configure-merge-methods.sh`) that mutate the org-wide ruleset and merge policy via the GitHub REST API.
- **Governance artifacts** (`governance/repository-governance.json`, `governance/repository-governance.schema.json`) that declare the desired state of branch protection across the org.

A vulnerability in any of these can compromise every `spark-match/*` repository (CI bypass, secret exfiltration, ruleset mutation, etc.). Treat security issues here with the same urgency as a vulnerability in a consumer repo.

## Supported Versions

This repo follows a **single-branch model** (`main`-only). The only supported version is the latest commit on `main`.

| Branch    | Supported | Notes |
|-----------|-----------|-------|
| `main`    | YES       | Patches shipped as fast-merge PRs and cherry-picks; consumers pin `@main` per `docs/VERSIONING.md`. |
| any other | NO        | Branches are deleted on merge; nothing to back-port to. |

There are no SemVer tags and no LTS branches. Consumers always pin `@main`.

## Reporting a Vulnerability

**DO NOT open a public GitHub issue for security vulnerabilities.**

Report privately via one of:

- **GitHub Security Advisories** (preferred): <https://github.com/spark-match/spark-match-01-devops/security/advisories/new>
- **Email**: ahincho@spark-match.dev (or open a GitHub issue and ask for a private channel if you do not have email access).

Include:

1. **What** is affected (workflow name, composite action, script, manifest field).
2. **How** it can be triggered (a specific workflow invocation, a manifest entry, an input combination).
3. **Impact** (ruleset bypass, secret leak, RCE in caller workflow, supply-chain compromise, etc.).
4. **Reproduction** steps (call a reusable with inputs `X` and `Y`, observe `Z`).
5. **Suggested fix** if you have one (optional but appreciated).

## Response Timeline

| Phase | Target |
|---|---|
| Acknowledgement | within 48 hours of receipt |
| Initial triage + severity assessment | within 7 days |
| Fix drafted (or mitigation published) | within 30 days for HIGH/CRITICAL, 90 days otherwise |
| Public disclosure | coordinated with the reporter; default 90 days from acknowledgement |

Timelines are aspirational. We will keep you informed of any slip.

## Out-of-Scope

The following are **not** considered vulnerabilities of this repo and should be reported via the normal public-issue channel:

- **Bugs in workflows the caller invokes incorrectly** (e.g. wrong input shape, missing permission). Use a regular GitHub issue.
- **Defects in upstream tools** (actionlint, yamllint, gitleaks, bats, pytest, jq, gh CLI). Report upstream.
- **Drift between the manifest and a repo's actual ruleset** that is not caused by a script bug. Use `gh issue` with the output of `./scripts/configure-repo-rulesets.sh --check --repos <name>`.

## Security Baseline (inherited)

This repo follows the org-wide security baseline documented in `docs/GOVERNANCE-STANDARD.md` § 6 (per repo). Key invariants:

- `permissions: minimum` on every workflow (never `write-all`).
- `secrets: inherit` is blocked cross-owner; deploy recipes use **same-name secret convention** (`AWS_DEPLOY_ROLE_ARN`, `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`).
- No `.env` files in the repo; secrets live in `gh secret` or Actions secrets only.
- CODE OWNERS review is required on every PR to `main` (ruleset field `require_code_owner_review: true`).
- Branch protection blocks direct pushes; admin bypass is scoped to the pull-request context.

## Security Tooling (current state, 2026-07-29)

See the `## Security` section in [README.md](README.md#security) for the full toolchain matrix. Summary:

- **Required CI checks**: actionlint, yamllint, gitleaks (on every PR + push)
- **CodeQL**: runs on PR + push + weekly; 502 alerts fixed across Sprints A/B/C (none open)
- **Dependabot security updates**: enabled (auto-PR for vulnerable deps)
- **Native GitHub secret scanning**: **disabled** (requires GitHub Advanced Security paid plan)
- **Gitleaks custom config**: `.gitleaks.toml` at repo root with custom AWS rules (`aws-account-id`, `aws-role-arn`, `aws-sts-session-token`) and allowlists for `tests/fixtures/`, `docs/`, `examples/*.md`, and `CHANGELOG.md`.
- **Pre-commit secret scan**: `.githooks/pre-commit` (gitleaks). Enable per clone via `git config core.hooksPath .githooks`. Catches secrets at commit time before they reach CI.

The repo's Free-plan posture is documented inline so future maintainers know why `gitleaks.yml` exists in the catalog and how to upgrade if/when `spark-match` moves to a paid plan.

### Enabling native GitHub secret scanning (admin task, no code change)

When the org moves to GitHub Advanced Security:

1. GitHub → repository **Settings** → **Code security and analysis**.
2. Enable **Secret scanning** (detects ~200 partner token formats that gitleaks may miss, including GitHub PATs, Slack tokens, Stripe keys, etc.).
3. Enable **Push protection** to block pushes containing detected secrets before they land on the remote.
4. Configure **custom patterns** for org-specific secrets if needed (org-level secret scanning settings).

Until that step is done, gitleaks is the sole secret scanner. See `.gitleaks.toml` for custom AWS rules that complement the default rule set.

## Acknowledgements

Security researchers who report valid, fixed vulnerabilities will be credited in the release notes unless they prefer anonymity.

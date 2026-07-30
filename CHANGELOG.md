# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
for pre-1.0 development: until `1.0.0` ships, breaking changes bump MINOR and new
features bump MINOR; only fixes bump PATCH. After `1.0.0` the standard SemVer
rules apply.

Versions are cut automatically by [`googleapis/release-please-action`](https://github.com/googleapis/release-please-action)
via `.github/workflows/release-please.yml`. Each merged PR that uses a
[Conventional Commits](https://www.conventionalcommits.org/) type (`feat`,
`fix`, `perf`, or anything with `BREAKING CHANGE:`) triggers a "release PR"
that:

1. Adds a bullet to the `[Unreleased]` section of `CHANGELOG.md`.
2. Bumps the version in `.release-please-manifest.json`.
3. Re-tags the section as `## [<new-version>]` and opens the release PR.

Merging the release PR creates the git tag + GitHub Release.

## [0.1.4](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.3...v0.1.4) (2026-07-30)


### Bug Fixes

* **trivy:** env-isolate inputs in Trivy summary step (closes 10 CodeQL alerts) ([#183](https://github.com/spark-match/spark-match-01-devops/issues/183)) ([04f4997](https://github.com/spark-match/spark-match-01-devops/commit/04f4997d8e93c9435f7c172f52a73694c8af73f5))


### CI/CD

* **container-deploy-ecr:** flip provenance+sbom defaults to true for SLSA Build L3 ([#179](https://github.com/spark-match/spark-match-01-devops/issues/179)) ([7469dde](https://github.com/spark-match/spark-match-01-devops/commit/7469dde13847a417c52acabb7745585b6a8f9535))
* **container-deploy-ecr:** opt-in cosign keyless signing per tag ([#182](https://github.com/spark-match/spark-match-01-devops/issues/182)) ([3326f17](https://github.com/spark-match/spark-match-01-devops/commit/3326f170bc7c01767b82f676a1c7e17198b8e154))
* **ecosystem:** add trivy reusable workflow (fs/image/config scan) ([#181](https://github.com/spark-match/spark-match-01-devops/issues/181)) ([9ce7f38](https://github.com/spark-match/spark-match-01-devops/commit/9ce7f380be09c298ae14990cc4b0469ff102160f))

## [0.1.3](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.2...v0.1.3) (2026-07-30)


### Documentation

* batch fixes — broken links, outdated counts, wrong versions, unverified PR refs ([#175](https://github.com/spark-match/spark-match-01-devops/issues/175)) ([9d43254](https://github.com/spark-match/spark-match-01-devops/commit/9d43254c06b41517998b35f740b29d3b6cd999b0))


### Tests

* **quality:** add multi-offender SAM fixture + scan tests/bats/helpers ([#178](https://github.com/spark-match/spark-match-01-devops/issues/178)) ([800b4b7](https://github.com/spark-match/spark-match-01-devops/commit/800b4b7cc3e7e00d0a339500f096770f590f9d49))

## [0.1.2](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.1...v0.1.2) (2026-07-29)


### Bug Fixes

* **reconciler:** implement --strict, --prune-unexpected; backup failure blocks PUT ([#169](https://github.com/spark-match/spark-match-01-devops/issues/169)) ([e7fddaf](https://github.com/spark-match/spark-match-01-devops/commit/e7fddaf5ca44cccf2c8375175b051bb7ab6b45c8))
* **release-please:** remove literal \ from header/footer ([#173](https://github.com/spark-match/spark-match-01-devops/issues/173)) ([c63e04b](https://github.com/spark-match/spark-match-01-devops/commit/c63e04b70775e5f2f937816a6a6ed163a7f98243))
* **release-please:** use release-type 'simple' (not 'default') ([#171](https://github.com/spark-match/spark-match-01-devops/issues/171)) ([5be42b1](https://github.com/spark-match/spark-match-01-devops/commit/5be42b1a5cd1ead14c0a793cacbbd11b1f6dbb06))

## [0.1.1](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.0...v0.1.1) (2026-07-29)


### Fixed

* **merge-methods:** -F typed booleans + propagate gh failures + --help exits 0 ([#162](https://github.com/spark-match/spark-match-01-devops/issues/162)) ([3ebc888](https://github.com/spark-match/spark-match-01-devops/commit/3ebc888369aa13c2266a36a8b4052f789bc73070))
* **reconciler:** capture numeric ruleset_id from POST response body ([#161](https://github.com/spark-match/spark-match-01-devops/issues/161)) ([643b958](https://github.com/spark-match/spark-match-01-devops/commit/643b958f89bd18525ddeff7663654e6616a0199b))
* **validate:** distinguish JSON null from boolean false in input checks ([#163](https://github.com/spark-match/spark-match-01-devops/issues/163)) ([575a6d4](https://github.com/spark-match/spark-match-01-devops/commit/575a6d44976cda44c6eb0c46bb6a93de0f0f717e))

## [0.1.0] - 2026-07-26

Initial release. Documents the catalog as of the 16-point improvement plan
sprint (see `CHANGELOG.md` for the migration entry; the original audit
lived in an external workspace doc that has since been retired).

### Added
- **Quality infra**: bats-core 1.11.1, shellcheck, JSON Schema + check-jsonschema reusable workflow under `.github/workflows/quality.yml` (#122).
- **Composite actions**: `validate-workflow-inputs` (JSON-Schema-driven enum/pattern/required validation) and `run-pytest-with-args` (uv + pytest arg assembly) under `.github/actions/` (#122).
- **README restructure**: Quick start table, 6-layer architecture, composite actions section, governance section, testing section, CACHE rate limits subsection (#126).
- **Community files**: `SECURITY.md` (vulnerability disclosure policy + supported versions + 48h/7d/30d/90d SLA), `CONTRIBUTING.md` (local setup + tests + style + PR workflow + admin bypass dance), `CODE_OF_CONDUCT.md` (Contributor Covenant v2.1) (#129).
- **PR/Issue templates**: `PULL_REQUEST_TEMPLATE.md` with 11-type conventional-commit checklist; `ISSUE_TEMPLATE/{config,bug,feature,docs}.yml` form-based templates with sensitive-report warnings routed to private channels (#130).
- **`.yamllint.yml` exemption** for `.github/ISSUE_TEMPLATE/` long placeholder lines; other rules still apply (#130).
- **CODEOWNERS-style path governance docs** in `CONTRIBUTING.md` and `README.md` (canonical pattern: explicit paths, no catch-all, double-owned for governance docs). Actual CODEOWNERS update is tracked in PR #12.

### Tests
- **pytest suite**: 15 tests for `scripts/check_lambda_permission_source_arn.py` over 5 SAM template fixtures (`sam-template-{valid,missing-sourcearn,comments-and-edges,mixed-resources,no-permissions}`) (#124).
- **bats suite for composite actions**: 19 tests for `validate-workflow-inputs` (`composite-validate.bats`) + 9 tests for `run-pytest-with-args` (`composite-run-pytest.bats`) (#125). Shared helper `helpers/common.bash` with stubs for `uv` and `pytest`.
- **bats suite for the reconciler**: 47 tests across 5 files (`reconciler-{prereqs,payload,check,apply,edge-cases}.bats`) covering argument parsing, manifest validation, payload construction (`build_desired_payload`), `--check` mode, `--apply` mode with PUT/POST/backup/dry-run, and edge cases (team-id cache reuse, CRLF, `--org` override, unknown manifest fields) (#128). Shared helper `helpers/reconciler.bash` with `gh` stub dispatching on URL pattern + HTTP method.

**Total automated tests**: 75 bats + 15 pytest = **90 tests**, all running on every PR via `.github/workflows/quality.yml`.

### Notes
- The catalog uses **single-branch model** (`main`-only); consumers pin `@main` per `docs/VERSIONING.md`. No SemVer tags until 1.0.0.
- The reconciler (`scripts/configure-repo-rulesets.sh`) is idempotent and supports `--check`, `--apply`, `--dry-run`, `--repos`, `--strict`, `--prune-unexpected`, `--json` flags; backed up to `backups/rulesets/<ts>/` before any PUT.
- The org-wide ruleset lives at `governance/repository-governance.json` (schema `spark-match.repository-governance/v2`, validated by `check-jsonschema` in CI); current compliance: 9 of 9 `spark-match/*` repos at 6/6 criteria per `docs/GOVERNANCE-STANDARD.md`.
- Out of scope for 0.1.0 (tracked separately): GPL-3.0 license migration (PR #8), dependabot extension (PR #11), CODEOWNERS file update (PR #12).

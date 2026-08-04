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

## [2.0.0](https://github.com/spark-match/spark-match-01-devops/compare/v1.0.2...v2.0.0) (2026-08-04)


### ⚠ BREAKING CHANGES

* AGENTS.md v1 contract.
* AGENTS.md v1 contract.

### Features

* **ci:** add CHANGELOG.md and release-please automation ([#131](https://github.com/spark-match/spark-match-01-devops/issues/131)) ([1741385](https://github.com/spark-match/spark-match-01-devops/commit/17413854a5651af2df9af6db3d97647a6fb10ce5))
* **ci:** add CI lint checks (actionlint + gitleaks + yamllint) ([#3](https://github.com/spark-match/spark-match-01-devops/issues/3)) ([7cb5a92](https://github.com/spark-match/spark-match-01-devops/commit/7cb5a92aca2903699d0e811ddf5a8fc4cd06712a))
* **ci:** add explicit input validation to terraform-plan reusable ([#25](https://github.com/spark-match/spark-match-01-devops/issues/25)) ([3f91cf8](https://github.com/spark-match/spark-match-01-devops/commit/3f91cf861475eb1c08e2a0718119ef448b4af1a9))
* **ci:** composite actions + refactor 20 reusable workflows ([#102](https://github.com/spark-match/spark-match-01-devops/issues/102)) ([08c2749](https://github.com/spark-match/spark-match-01-devops/commit/08c27495fd5ba635d79f72a3aeeb7a779e159bb5))
* **ci:** make terraform reusables N-environment aware ([#7](https://github.com/spark-match/spark-match-01-devops/issues/7)) ([f759f3e](https://github.com/spark-match/spark-match-01-devops/commit/f759f3e510ab1cb4c410d9e1b07318100b443b1d))
* **composite:** extract bats-runner from reusable-quality.yml ([#220](https://github.com/spark-match/spark-match-01-devops/issues/220)) ([e234adf](https://github.com/spark-match/spark-match-01-devops/commit/e234adf81c5798ab598afc7b79ccea3997ecdbe5))
* **deploy:** angular-spa-deploy recipe reusable para ORION SPA ([#52](https://github.com/spark-match/spark-match-01-devops/issues/52)) ([6b19936](https://github.com/spark-match/spark-match-01-devops/commit/6b19936584088c2240b7d89bfe48c1e8459306d1))
* **deploy:** enriched step summary (CF domain + bundle fingerprint + sync counts) ([#67](https://github.com/spark-match/spark-match-01-devops/issues/67)) ([ff540e6](https://github.com/spark-match/spark-match-01-devops/commit/ff540e6ad958b932b0f5e37c4b578fe8192b9d00))
* **destroy:** add post-destroy cleanup job for log groups/SSM/orphan buckets/CF stacks ([#100](https://github.com/spark-match/spark-match-01-devops/issues/100)) ([742c39f](https://github.com/spark-match/spark-match-01-devops/commit/742c39f0f7f71dcdae611103ffc7c284596da893))
* **devops:** make CodeQL a reusable workflow (multi-language, blocking) ([eebfd94](https://github.com/spark-match/spark-match-01-devops/commit/eebfd94842b2f6a50072fea04a496117a461083f))
* **devops:** make CodeQL a reusable workflow (multi-language, blocking) ([#142](https://github.com/spark-match/spark-match-01-devops/issues/142)) ([eebfd94](https://github.com/spark-match/spark-match-01-devops/commit/eebfd94842b2f6a50072fea04a496117a461083f))
* **devops:** use spark-match-bot GitHub App for release-please auth ([34b5c6b](https://github.com/spark-match/spark-match-01-devops/commit/34b5c6b7b18c0d17110d723fe65f7f77cf1252f1))
* **devops:** use spark-match-bot GitHub App for release-please auth ([#159](https://github.com/spark-match/spark-match-01-devops/issues/159)) ([34b5c6b](https://github.com/spark-match/spark-match-01-devops/commit/34b5c6b7b18c0d17110d723fe65f7f77cf1252f1))
* **governance:** extend manifest to all 9 spark-match org repos ([#115](https://github.com/spark-match/spark-match-01-devops/issues/115)) ([d271d0d](https://github.com/spark-match/spark-match-01-devops/commit/d271d0d9f525af5837ee19bdf73f7571ae62fc72))
* **governance:** reconcile repository rulesets from manifest ([#109](https://github.com/spark-match/spark-match-01-devops/issues/109)) ([52cd50e](https://github.com/spark-match/spark-match-01-devops/commit/52cd50e1548f2f47304ae67157610325944b4362))
* **node:** add node-typecheck and node-build reusables ([#120](https://github.com/spark-match/spark-match-01-devops/issues/120)) ([f53e144](https://github.com/spark-match/spark-match-01-devops/commit/f53e1446b228b94366d4493eb67ad486267e926c))
* **node:** node-test.yml reusable for unit test jobs ([#65](https://github.com/spark-match/spark-match-01-devops/issues/65)) ([9e5b03b](https://github.com/spark-match/spark-match-01-devops/commit/9e5b03ba9c2c0253e047cd30945e2ed8f796586a))
* **quality:** add bats, shellcheck and JSON Schema infrastructure ([#122](https://github.com/spark-match/spark-match-01-devops/issues/122)) ([58153ad](https://github.com/spark-match/spark-match-01-devops/commit/58153ad2de0c4568e85e132e790d306dcc83ecef))
* refresh agents.md for v1.0.0 release ([#264](https://github.com/spark-match/spark-match-01-devops/issues/264)) ([5801770](https://github.com/spark-match/spark-match-01-devops/commit/580177003686a49d2144c6589f41b8f8549027de))
* refresh agents.md for v1.0.0 release ([#271](https://github.com/spark-match/spark-match-01-devops/issues/271)) ([db7a768](https://github.com/spark-match/spark-match-01-devops/commit/db7a7681f4c8e0b62e3532eec65586d3de167055))
* reusable workflows for terraform + latex ([#1](https://github.com/spark-match/spark-match-01-devops/issues/1)) ([6478e1e](https://github.com/spark-match/spark-match-01-devops/commit/6478e1ef496aa45833424772a1d2c615acb5f432))
* **reusables:** cache key convention v4 (pkgmanager + env + lowercase) ([#62](https://github.com/spark-match/spark-match-01-devops/issues/62)) ([3e30cdc](https://github.com/spark-match/spark-match-01-devops/commit/3e30cdc11a81c5e3a8eab9d43589d8a58521956f))
* **reusables:** per-env npm cache + working-directory input ([#55](https://github.com/spark-match/spark-match-01-devops/issues/55)) ([d5b4f79](https://github.com/spark-match/spark-match-01-devops/commit/d5b4f79dda4a35008f25b0b08ed075b1695b4ac3))
* **scripts:** add configure-merge-methods.sh ([#5](https://github.com/spark-match/spark-match-01-devops/issues/5)) ([05f23e0](https://github.com/spark-match/spark-match-01-devops/commit/05f23e089c89cc4dbaa2e23d6bb320ddf3af65b8))
* **scripts:** add configure-repo-rulesets.sh ([#11](https://github.com/spark-match/spark-match-01-devops/issues/11)) ([0398a13](https://github.com/spark-match/spark-match-01-devops/commit/0398a13f9cdc1851e220cd596af708d9d22ed414))
* **scripts:** add create-pr helper (ps1 + sh) to avoid JSON body malformation ([#26](https://github.com/spark-match/spark-match-01-devops/issues/26)) ([5d5c939](https://github.com/spark-match/spark-match-01-devops/commit/5d5c939284c567c9b9f2aaa35acb2a3ac2b31c1c))
* **scripts:** add OrganizationAdmin bypass_actors to rulesets ([#14](https://github.com/spark-match/spark-match-01-devops/issues/14)) ([2f090a5](https://github.com/spark-match/spark-match-01-devops/commit/2f090a5e128cbb0341730527abf8c2130501dfbe))
* **scripts:** ruleset with full pull_request rule coverage ([#13](https://github.com/spark-match/spark-match-01-devops/issues/13)) ([b70bb8e](https://github.com/spark-match/spark-match-01-devops/commit/b70bb8ea66274eab94c576a47ffdb7b5d54412d0))
* **workflows:** extract commitlint + release-please into shared reusables ([#254](https://github.com/spark-match/spark-match-01-devops/issues/254)) ([e7618a7](https://github.com/spark-match/spark-match-01-devops/commit/e7618a71e995d7da2bdcd9eb641f897fe2ea6f89))
* **workflows:** real pnpm/yarn/bun support across node reusables ([#226](https://github.com/spark-match/spark-match-01-devops/issues/226)) ([df4e515](https://github.com/spark-match/spark-match-01-devops/commit/df4e515cb8becf063ceed9eac3ca3dc3685037eb))


### Bug Fixes

* **actions:** invoke composite scripts via explicit bash ([b1c47e5](https://github.com/spark-match/spark-match-01-devops/commit/b1c47e59b36c03cfefaa85785ee80721df3063d6))
* **cfn-nag:** drop --config-path (not supported by cfn_nag_scan 0.8.10) ([d7e49bc](https://github.com/spark-match/spark-match-01-devops/commit/d7e49bc86c319ffc379281d4c65053aef74a4a82))
* **cfn-nag:** scan per-file to exclude .aws-sam/build/template.yaml ([#83](https://github.com/spark-match/spark-match-01-devops/issues/83)) ([19046eb](https://github.com/spark-match/spark-match-01-devops/commit/19046eb0c8a751ee5d9b408420bd24a3d388869c))
* **ci:** allow deps scope in commitlint (dependabot) ([#247](https://github.com/spark-match/spark-match-01-devops/issues/247)) ([40e8361](https://github.com/spark-match/spark-match-01-devops/commit/40e836122960a22c41f213df41baa408266d68c9))
* **ci:** commitlint commit-depth=2 + short merge body template ([#216](https://github.com/spark-match/spark-match-01-devops/issues/216)) ([03c9ba9](https://github.com/spark-match/spark-match-01-devops/commit/03c9ba93ed4ce6d7b7fc326bf197ff78d4cd1e41))
* **ci:** disable body-max-line-length so dependabot bumps pass ([#244](https://github.com/spark-match/spark-match-01-devops/issues/244)) ([98243cd](https://github.com/spark-match/spark-match-01-devops/commit/98243cd54e0d4a7dd6ced9a7a1946032c3d7bd8e))
* **ci:** disable body-max-line-length so dependabot bumps pass ([#246](https://github.com/spark-match/spark-match-01-devops/issues/246)) ([47baeff](https://github.com/spark-match/spark-match-01-devops/commit/47baeffd7520f52fb304cf810b44082baa77aa93))
* **ci:** reference composite actions via cross-repo path ([a6d9879](https://github.com/spark-match/spark-match-01-devops/commit/a6d987981583cbb4453b57d2bfe2323b85656508))
* **ci:** restore missing `steps:` keyword in 14 recipes ([87e50a8](https://github.com/spark-match/spark-match-01-devops/commit/87e50a82e4747b8c41d876e6bb8ec9bcfcbb7da8))
* **ci:** skip commitlint for release-please branches ([#214](https://github.com/spark-match/spark-match-01-devops/issues/214)) ([befbb4b](https://github.com/spark-match/spark-match-01-devops/commit/befbb4b58f130c68ce2f04f38c1750a599103e6c))
* **ci:** skip commitlint on push when head commit is a release ([#222](https://github.com/spark-match/spark-match-01-devops/issues/222)) ([5cc015b](https://github.com/spark-match/spark-match-01-devops/commit/5cc015bfb553aceb7b74a9283ecb175f1cab9cdf))
* **cleanup-merged-branches:** handle 'remote already deleted' case ([#193](https://github.com/spark-match/spark-match-01-devops/issues/193)) ([d693862](https://github.com/spark-match/spark-match-01-devops/commit/d693862177a6e87cae66f5c196283fd0e16313e6))
* **codeowners:** add github-actions[bot] to release-please managed paths ([#140](https://github.com/spark-match/spark-match-01-devops/issues/140)) ([d1eeb16](https://github.com/spark-match/spark-match-01-devops/commit/d1eeb16079971c65503cd46f3115e3ea385e6750))
* **codeowners:** align header text with ruleset (compliance 6/6) ([#118](https://github.com/spark-match/spark-match-01-devops/issues/118)) ([2efa0bb](https://github.com/spark-match/spark-match-01-devops/commit/2efa0bbd2c36388a5e450982ec51aa5138cb13bc))
* **codeowners:** cover /docs /governance and /LICENSE in 01-devops ([#119](https://github.com/spark-match/spark-match-01-devops/issues/119)) ([2d4593e](https://github.com/spark-match/spark-match-01-devops/commit/2d4593e9ee5bbfb65b26f8122a1c9f1db112403b))
* **codeowners:** use [@github-actions](https://github.com/github-actions) (without [bot]) for release-please managed paths ([#141](https://github.com/spark-match/spark-match-01-devops/issues/141)) ([486b1a1](https://github.com/spark-match/spark-match-01-devops/commit/486b1a18b5231dba2b8c5d588fa7eeb6da10cd24))
* **composite:** kebab-case name and align step ids with step names ([#248](https://github.com/spark-match/spark-match-01-devops/issues/248)) ([df58942](https://github.com/spark-match/spark-match-01-devops/commit/df58942e45e3af36fb5ffa1a62181927a9cefc50))
* **deploy:** quote jq default value in invalidation_id extraction ([#72](https://github.com/spark-match/spark-match-01-devops/issues/72)) ([c1eb220](https://github.com/spark-match/spark-match-01-devops/commit/c1eb220b60d95a874e7a3ae5bf5d7f01a76a7084))
* **devops:** compact release-please-config.json (yamllint 33 -&gt; 0 ([d8b128c](https://github.com/spark-match/spark-match-01-devops/commit/d8b128c31046b475be607d6e04daa281590ac3cc))
* **devops:** compact release-please-config.json (yamllint 33 -&gt; 0 errors) ([#149](https://github.com/spark-match/spark-match-01-devops/issues/149)) ([d8b128c](https://github.com/spark-match/spark-match-01-devops/commit/d8b128c31046b475be607d6e04daa281590ac3cc))
* **devops:** env-isolate inputs/github in AWS deploy run blocks (closes ([baf321d](https://github.com/spark-match/spark-match-01-devops/commit/baf321d753da009cdae960d4eb7dfbfca7bb34a5))
* **devops:** env-isolate inputs/github in AWS deploy run blocks (closes 107 code-injection alerts) ([#152](https://github.com/spark-match/spark-match-01-devops/issues/152)) ([baf321d](https://github.com/spark-match/spark-match-01-devops/commit/baf321d753da009cdae960d4eb7dfbfca7bb34a5))
* **devops:** env-isolate inputs/github in terraform-* run blocks (closes ([4447d16](https://github.com/spark-match/spark-match-01-devops/commit/4447d16e6142da43e926390d6c1a0ed032c0bfd5))
* **devops:** env-isolate inputs/github in terraform-* run blocks (closes 132 code-injection alerts) ([#151](https://github.com/spark-match/spark-match-01-devops/issues/151)) ([4447d16](https://github.com/spark-match/spark-match-01-devops/commit/4447d16e6142da43e926390d6c1a0ed032c0bfd5))
* **devops:** env-isolate inputs/steps/job in language stack run blocks ([9274943](https://github.com/spark-match/spark-match-01-devops/commit/9274943cee4f3878cfea5fdf6966b8b2c4e1a0e8))
* **devops:** env-isolate inputs/steps/job in language stack run blocks (closes 105 code-injection alerts) ([#153](https://github.com/spark-match/spark-match-01-devops/issues/153)) ([9274943](https://github.com/spark-match/spark-match-01-devops/commit/9274943cee4f3878cfea5fdf6966b8b2c4e1a0e8))
* **devops:** env-isolate inputs/steps/job in remaining run blocks ([def0fa6](https://github.com/spark-match/spark-match-01-devops/commit/def0fa6a7ba0fd1e7b958e0ffaaf7c8195e3a9d6))
* **devops:** env-isolate inputs/steps/job in remaining run blocks (closes 55 code-injection alerts) ([#154](https://github.com/spark-match/spark-match-01-devops/issues/154)) ([def0fa6](https://github.com/spark-match/spark-match-01-devops/commit/def0fa6a7ba0fd1e7b958e0ffaaf7c8195e3a9d6))
* **devops:** env-isolate steps/job in Wave 1-2 stragglers (closes 33 ([3ff8444](https://github.com/spark-match/spark-match-01-devops/commit/3ff8444a568b447a7db02854a6eb48859d8a63ca))
* **devops:** env-isolate steps/job in Wave 1-2 stragglers (closes 33 code-injection alerts) ([#155](https://github.com/spark-match/spark-match-01-devops/issues/155)) ([3ff8444](https://github.com/spark-match/spark-match-01-devops/commit/3ff8444a568b447a7db02854a6eb48859d8a63ca))
* **devops:** jq -nc --arg for clean JSON output (newline in GITHUB_OUTPUT broke parsing) ([#145](https://github.com/spark-match/spark-match-01-devops/issues/145)) ([952fcc4](https://github.com/spark-match/spark-match-01-devops/commit/952fcc401213de2e5eda92d220e77611880de60e))
* **devops:** pass inputs.languages via env to avoid shell interpolation (CodeQL [#484](https://github.com/spark-match/spark-match-01-devops/issues/484)) ([#146](https://github.com/spark-match/spark-match-01-devops/issues/146)) ([f5f369f](https://github.com/spark-match/spark-match-01-devops/commit/f5f369fc9a791be2dcccd7f84be6c71cf1c45fd1))
* **devops:** pass inputs.languages via env to avoid shell interpolation (CodeQL [#484](https://github.com/spark-match/spark-match-01-devops/issues/484)) ([#147](https://github.com/spark-match/spark-match-01-devops/issues/147)) ([69b44aa](https://github.com/spark-match/spark-match-01-devops/commit/69b44aaa90573d8704234ce96cae04663907c0f5))
* **devops:** remove concurrency block from codeql reusable (deadlock) ([0646ce1](https://github.com/spark-match/spark-match-01-devops/commit/0646ce1098e280a2f2f66b706849251b5c09e125))
* **devops:** remove concurrency from codeql reusable (deadlock with caller) ([#143](https://github.com/spark-match/spark-match-01-devops/issues/143)) ([0646ce1](https://github.com/spark-match/spark-match-01-devops/commit/0646ce1098e280a2f2f66b706849251b5c09e125))
* **devops:** remove paths-ignore from codeql reusable (actionlint regression [#142](https://github.com/spark-match/spark-match-01-devops/issues/142)) ([#148](https://github.com/spark-match/spark-match-01-devops/issues/148)) ([c5e1caa](https://github.com/spark-match/spark-match-01-devops/commit/c5e1caa6e762e6cc85dc18364044844745add156))
* **devops:** replace printf | tr with bash \ lowercase (closes 7 alerts) ([#156](https://github.com/spark-match/spark-match-01-devops/issues/156)) ([c81ca41](https://github.com/spark-match/spark-match-01-devops/commit/c81ca418dcca485b9da4841840d42d38dc93c866))
* **devops:** replace printf | tr with bash ${VAR,,} lowercase (closes 7 ([c81ca41](https://github.com/spark-match/spark-match-01-devops/commit/c81ca418dcca485b9da4841840d42d38dc93c866))
* **devops:** SHA-pin all third-party GitHub Actions (closes 71 ([a01bbc4](https://github.com/spark-match/spark-match-01-devops/commit/a01bbc40b6e6bef8d8082af16061985281102986))
* **devops:** SHA-pin all third-party GitHub Actions (closes 71 unpinned-tag alerts) ([#150](https://github.com/spark-match/spark-match-01-devops/issues/150)) ([a01bbc4](https://github.com/spark-match/spark-match-01-devops/commit/a01bbc40b6e6bef8d8082af16061985281102986))
* **devops:** split() for codeql matrix (format() does not split on ([0534176](https://github.com/spark-match/spark-match-01-devops/commit/0534176d3d5a0087ccb8db7c3dea444929c4d75f))
* **devops:** split() for codeql matrix (format() does not split on commas) ([#144](https://github.com/spark-match/spark-match-01-devops/issues/144)) ([0534176](https://github.com/spark-match/spark-match-01-devops/commit/0534176d3d5a0087ccb8db7c3dea444929c4d75f))
* **devops:** strip newlines from env values written to $GITHUB_ENV (closes 6 envvar-injection alerts) ([#157](https://github.com/spark-match/spark-match-01-devops/issues/157)) ([f746451](https://github.com/spark-match/spark-match-01-devops/commit/f746451bdc4637d128704d89e1323fa19f9bf5d7))
* **gitignore:** reglas correctas para GitHub Actions (sin Terraform/LaTeX) ([611e266](https://github.com/spark-match/spark-match-01-devops/commit/611e2666c7eaab4f37daae288d832a5bd3729fbe))
* **governance:** align status check names with reported job names ([afaaea3](https://github.com/spark-match/spark-match-01-devops/commit/afaaea37ced02211a0a9b6280134368dfcc7f5d2))
* **governance:** align status check names with reported job names ([#273](https://github.com/spark-match/spark-match-01-devops/issues/273)) ([afaaea3](https://github.com/spark-match/spark-match-01-devops/commit/afaaea37ced02211a0a9b6280134368dfcc7f5d2))
* **governance:** CODE OWNERS técnicos, sin product-owners como catch-all ([cc81424](https://github.com/spark-match/spark-match-01-devops/commit/cc814246f3f2ef00d126b8c4033417a7e3d9b7f9))
* **governance:** CODEOWNERS simplificado a solo devops ([2a43e0b](https://github.com/spark-match/spark-match-01-devops/commit/2a43e0b37a74eb0adc9092fe0b23ddc5802cfdbd))
* **governance:** correct spark-match-02-infrastructure Checkov status check name ([#111](https://github.com/spark-match/spark-match-01-devops/issues/111)) ([6399df5](https://github.com/spark-match/spark-match-01-devops/commit/6399df54ab19e205020c094218a5f82e74b74e63))
* **governance:** reconcile 02-infrastructure status-checks vs reported contexts ([#274](https://github.com/spark-match/spark-match-01-devops/issues/274)) ([e7bdf9b](https://github.com/spark-match/spark-match-01-devops/commit/e7bdf9be3f437b927567af1b4c942bdd307246ab))
* **governance:** require commitlint-main check to gate squash merges ([#276](https://github.com/spark-match/spark-match-01-devops/issues/276)) ([57cf590](https://github.com/spark-match/spark-match-01-devops/commit/57cf590060cc8957708dcc2f79a7db357de9180c))
* **governance:** set requireCodeOwnerReview=true and document CODEOWNERS choice ([#113](https://github.com/spark-match/spark-match-01-devops/issues/113)) ([084959c](https://github.com/spark-match/spark-match-01-devops/commit/084959c671cc039cd06a50b90924f0a957b7d07f))
* **merge-methods:** -F typed booleans + propagate gh failures + --help exits 0 ([#162](https://github.com/spark-match/spark-match-01-devops/issues/162)) ([3ebc888](https://github.com/spark-match/spark-match-01-devops/commit/3ebc888369aa13c2266a36a8b4052f789bc73070))
* **migrations-dry-run:** drop redundant CLI forwarding, fix v9 --schema array bug ([#93](https://github.com/spark-match/spark-match-01-devops/issues/93)) ([a47a6b2](https://github.com/spark-match/spark-match-01-devops/commit/a47a6b2d98acb41ab3ebe17a39f72d4b49309b20))
* **migrations-dry-run:** restore d8b819c's drop-forwarding recipe on main ([#94](https://github.com/spark-match/spark-match-01-devops/issues/94)) ([64d8cc3](https://github.com/spark-match/spark-match-01-devops/commit/64d8cc33be96f146def08bbf5fd90f4f9ad21343))
* **python-ci:** replace IFS+here-string array with --group flag loop ([b507860](https://github.com/spark-match/spark-match-01-devops/commit/b507860beff7a009249d74fa88d2f85eb6437f6f))
* **python-ci:** replace IFS+here-string array with --group flag loop ([#75](https://github.com/spark-match/spark-match-01-devops/issues/75)) ([b507860](https://github.com/spark-match/spark-match-01-devops/commit/b507860beff7a009249d74fa88d2f85eb6437f6f))
* **python:** W1 workaround - hardcode matrix python-version (cross-owner fix) ([#74](https://github.com/spark-match/spark-match-01-devops/issues/74)) ([d68efc6](https://github.com/spark-match/spark-match-01-devops/commit/d68efc695d250dd7c12f4dde6a2a0659ca5b1867))
* **python:** W1 workaround for cross-owner matrix bug (hardcode ([d68efc6](https://github.com/spark-match/spark-match-01-devops/commit/d68efc695d250dd7c12f4dde6a2a0659ca5b1867))
* **quality:** allow x.y.z major &gt;=1 in release-please manifest bats regex ([cf4d873](https://github.com/spark-match/spark-match-01-devops/commit/cf4d8737fe7accb3f907865f2a07edf4d1cee22a))
* **quality:** allow x.y.z major &gt;=1 in release-please manifest bats regex ([#266](https://github.com/spark-match/spark-match-01-devops/issues/266)) ([d11d2c0](https://github.com/spark-match/spark-match-01-devops/commit/d11d2c079fca6a177614092a3ce05f7b62b88482))
* **quality:** allow x.y.z major &gt;=1 in release-please manifest bats regex ([#272](https://github.com/spark-match/spark-match-01-devops/issues/272)) ([cf4d873](https://github.com/spark-match/spark-match-01-devops/commit/cf4d8737fe7accb3f907865f2a07edf4d1cee22a))
* **reconciler:** capture numeric ruleset_id from POST response body ([#161](https://github.com/spark-match/spark-match-01-devops/issues/161)) ([643b958](https://github.com/spark-match/spark-match-01-devops/commit/643b958f89bd18525ddeff7663654e6616a0199b))
* **reconciler:** implement --strict, --prune-unexpected; backup failure blocks PUT ([#169](https://github.com/spark-match/spark-match-01-devops/issues/169)) ([e7fddaf](https://github.com/spark-match/spark-match-01-devops/commit/e7fddaf5ca44cccf2c8375175b051bb7ab6b45c8))
* **reconciler:** strip CR from repo names and assemble JSON via jq --argjson ([#112](https://github.com/spark-match/spark-match-01-devops/issues/112)) ([6db7de8](https://github.com/spark-match/spark-match-01-devops/commit/6db7de8f9939b7457fa7973aba81cca53780553d))
* **release-please:** drop _copyright from manifest ([#139](https://github.com/spark-match/spark-match-01-devops/issues/139)) ([0fc20cc](https://github.com/spark-match/spark-match-01-devops/commit/0fc20ccca1c852fd29d84a1337bedb5609973d16))
* **release-please:** remove literal \ from header/footer ([#173](https://github.com/spark-match/spark-match-01-devops/issues/173)) ([c63e04b](https://github.com/spark-match/spark-match-01-devops/commit/c63e04b70775e5f2f937816a6a6ed163a7f98243))
* **release-please:** use release-type 'simple' (not 'default') ([#171](https://github.com/spark-match/spark-match-01-devops/issues/171)) ([5be42b1](https://github.com/spark-match/spark-match-01-devops/commit/5be42b1a5cd1ead14c0a793cacbbd11b1f6dbb06))
* **repo:** align commit-msg hook with header-max-length ci rule ([#253](https://github.com/spark-match/spark-match-01-devops/issues/253)) ([5405471](https://github.com/spark-match/spark-match-01-devops/commit/5405471ea88709ba8c87cd25e5e24cd2f06c38e2))
* **repo:** split sbom generation from release upload (anchore v0.24.0 regression) ([#260](https://github.com/spark-match/spark-match-01-devops/issues/260)) ([cc96f19](https://github.com/spark-match/spark-match-01-devops/commit/cc96f196e83b5e28f67368bf9362e620d1c7eccc))
* **repo:** split sbom generation from release upload (anchore v0.24.0 regression). All 9 checks green. Merged via REST API direct. ([cc96f19](https://github.com/spark-match/spark-match-01-devops/commit/cc96f196e83b5e28f67368bf9362e620d1c7eccc))
* **sbom:** download SBOM artifact for verify step + drop redundant gh release upload ([#198](https://github.com/spark-match/spark-match-01-devops/issues/198)) ([900b70f](https://github.com/spark-match/spark-match-01-devops/commit/900b70f317ac26c45384a884c9c58362f04d4452))
* **sonar:** add always() to enforcement if (QG step exits 1, blocking subsequent if eval) ([8bbd580](https://github.com/spark-match/spark-match-01-devops/commit/8bbd580ef5c36f1482ab9688370aa572e1efa1cf))
* **sonar:** continue-on-error on QG step so enforcement is caller-controlled ([61245fa](https://github.com/spark-match/spark-match-01-devops/commit/61245faf80bd724cba2fcc8455ace00bbcf09a89))
* **sonar:** correct action prefix for sonarqube-quality-gate-action ([#103](https://github.com/spark-match/spark-match-01-devops/issues/103)) ([e034e98](https://github.com/spark-match/spark-match-01-devops/commit/e034e9821f44748566ff49396836598aea10da16))
* **sonar:** declare fail-on-quality-gate as string + custom enforcement step ([#105](https://github.com/spark-match/spark-match-01-devops/issues/105)) ([eb04a09](https://github.com/spark-match/spark-match-01-devops/commit/eb04a090d235c6d4c63c6e725498017b9a323beb))
* **sonar:** declare SONAR_TOKEN as required secret in recipes ([5efd4c1](https://github.com/spark-match/spark-match-01-devops/commit/5efd4c109a5b95cc239b63084a0682886d2a8854))
* **sonar:** declare SONAR_TOKEN as required secret in recipes ([#104](https://github.com/spark-match/spark-match-01-devops/issues/104)) ([5efd4c1](https://github.com/spark-match/spark-match-01-devops/commit/5efd4c109a5b95cc239b63084a0682886d2a8854))
* **sonar:** drop projectName from scanner args ([c8d7b60](https://github.com/spark-match/spark-match-01-devops/commit/c8d7b6065684828f0588e6cfb6e6dda5a8fef4d7))
* **sonar:** drop projectName from scanner args ([a43b5e3](https://github.com/spark-match/spark-match-01-devops/commit/a43b5e3e095fddf8af32a227e2b4eec3633d97f2))
* **sonar:** fail loud on QG timeout + cache scanner + skip architecture sensor ([#117](https://github.com/spark-match/spark-match-01-devops/issues/117)) ([15e2309](https://github.com/spark-match/spark-match-01-devops/commit/15e2309ff785aa7b946dcb57822011f8205609a0))
* **trivy:** env-isolate inputs in Trivy summary step (closes 10 CodeQL alerts) ([#183](https://github.com/spark-match/spark-match-01-devops/issues/183)) ([04f4997](https://github.com/spark-match/spark-match-01-devops/commit/04f4997d8e93c9435f7c172f52a73694c8af73f5))
* **validate:** distinguish JSON null from boolean false in input checks ([#163](https://github.com/spark-match/spark-match-01-devops/issues/163)) ([575a6d4](https://github.com/spark-match/spark-match-01-devops/commit/575a6d44976cda44c6eb0c46bb6a93de0f0f717e))
* **workflow:** replace regex_replace with shell step in latex-build ([#2](https://github.com/spark-match/spark-match-01-devops/issues/2)) ([224d28f](https://github.com/spark-match/spark-match-01-devops/commit/224d28fc8f0f445de3727a866e2657b91ce48444))
* **workflows:** accept apply-role-arn as string input (mirror plan) ([#242](https://github.com/spark-match/spark-match-01-devops/issues/242)) ([079fb17](https://github.com/spark-match/spark-match-01-devops/commit/079fb17bfba017e62ffc5679a74d21d7e17ddb83))
* **workflows:** accept plan-role-arn as string input to bypass cross-owner secret masking ([#241](https://github.com/spark-match/spark-match-01-devops/issues/241)) ([46f4989](https://github.com/spark-match/spark-match-01-devops/commit/46f49890a977a9294799448f9061d13924528a28))
* **workflows:** add hex16 diag to bypass log masking of role arn ([#240](https://github.com/spark-match/spark-match-01-devops/issues/240)) ([79336de](https://github.com/spark-match/spark-match-01-devops/commit/79336dee63f0ec87c7bae31c6f92e4ee78608d2c))
* **workflows:** bind reusable-terraform-plan job to gh environment ([#228](https://github.com/spark-match/spark-match-01-devops/issues/228)) ([82f8da0](https://github.com/spark-match/spark-match-01-devops/commit/82f8da0cf8becc713d2c4bc8b4c85375a486ccc3))
* **workflows:** detect role arn format in diag step (plan only) ([#238](https://github.com/spark-match/spark-match-01-devops/issues/238)) ([3aa4e0c](https://github.com/spark-match/spark-match-01-devops/commit/3aa4e0c51ae3e123d8620e3f89b7eae963b67ca8))
* **workflows:** env-isolate step outputs in quality.yml + release-please.yml ([#184](https://github.com/spark-match/spark-match-01-devops/issues/184)) ([65d64d5](https://github.com/spark-match/spark-match-01-devops/commit/65d64d59aa8b4d6a1604e0f347bc10b280c6654a))
* **workflows:** look up aws role arn via plan/apply-role-arn-secret input ([#232](https://github.com/spark-match/spark-match-01-devops/issues/232)) ([29ab3ad](https://github.com/spark-match/spark-match-01-devops/commit/29ab3add8b0365260797e9ad26148424fd25372b))
* **workflows:** make aws role arn secrets optional ([#243](https://github.com/spark-match/spark-match-01-devops/issues/243)) ([320c799](https://github.com/spark-match/spark-match-01-devops/commit/320c7993cfeb6b0be73dac0970b5582b6d77b4d1))
* **workflows:** make aws role arn secrets optional for env-scoped lookup ([#229](https://github.com/spark-match/spark-match-01-devops/issues/229)) ([9887618](https://github.com/spark-match/spark-match-01-devops/commit/98876188c5d64ece652f9eac5b163cd86b9dcd91))
* **workflows:** pass release-please secrets via workflow_call secrets block ([#256](https://github.com/spark-match/spark-match-01-devops/issues/256)) ([800177d](https://github.com/spark-match/spark-match-01-devops/commit/800177d4dcce149dc95a0769dbf62185f70574a9))
* **workflows:** remove aws role arn secrets decl; rely on env binding ([#231](https://github.com/spark-match/spark-match-01-devops/issues/231)) ([69f4d97](https://github.com/spark-match/spark-match-01-devops/commit/69f4d97ec7f8be6a78e645e9f51bcf944852ace0))
* **workflows:** remove concurrency blocks from reusable ci workflows ([#255](https://github.com/spark-match/spark-match-01-devops/issues/255)) ([32f8e0d](https://github.com/spark-match/spark-match-01-devops/commit/32f8e0d651caa3aead979bb9ccf87a5c5860aa21))
* **workflows:** remove duplicate Resolve environment identifier step ([#19](https://github.com/spark-match/spark-match-01-devops/issues/19)) ([6e25fe2](https://github.com/spark-match/spark-match-01-devops/commit/6e25fe26db8c0f3bbe6103bea2ebf5900e44f112))
* **workflows:** revert dynamic secret lookup; restore standard cross-owner pattern ([#234](https://github.com/spark-match/spark-match-01-devops/issues/234)) ([d9a6fca](https://github.com/spark-match/spark-match-01-devops/commit/d9a6fcaf9ca1861590e387c2b48bf6a0e81b8d18))
* **workflows:** set working-directory on pre-checkout env step ([eb34d88](https://github.com/spark-match/spark-match-01-devops/commit/eb34d886a9a9b3462ba1e30a7d051dc8fbe8c61a))
* **workflows:** simplify reusable-terraform-plan env binding to single input ([#262](https://github.com/spark-match/spark-match-01-devops/issues/262)) ([1dc78c0](https://github.com/spark-match/spark-match-01-devops/commit/1dc78c0209ad3ba611f2edc2a4eac62393a44641))


### Reverts

* **docs:** refresh agents.md for v1.0.0 to undo pull request 264 ([161bb8e](https://github.com/spark-match/spark-match-01-devops/commit/161bb8e09ba2d5d1f201e61fd3f857bbf337c5df))
* **docs:** refresh agents.md for v1.0.0 to undo pull request 264 ([#270](https://github.com/spark-match/spark-match-01-devops/issues/270)) ([161bb8e](https://github.com/spark-match/spark-match-01-devops/commit/161bb8e09ba2d5d1f201e61fd3f857bbf337c5df))
* **quality:** bats regex v1 allow to undo pull request 266 ([5e7bef7](https://github.com/spark-match/spark-match-01-devops/commit/5e7bef704aae5430317cc9b6acfcb5a9af9e975c))
* **quality:** bats regex v1 allow to undo pull request 266 ([#269](https://github.com/spark-match/spark-match-01-devops/issues/269)) ([5e7bef7](https://github.com/spark-match/spark-match-01-devops/commit/5e7bef704aae5430317cc9b6acfcb5a9af9e975c))
* **repo:** release 1.0.0 to undo pull request 265 ([676a684](https://github.com/spark-match/spark-match-01-devops/commit/676a6845361f615edebf1211891e6419b38ac9ea))
* **repo:** release 1.0.0 to undo pull request 265 ([#267](https://github.com/spark-match/spark-match-01-devops/issues/267)) ([676a684](https://github.com/spark-match/spark-match-01-devops/commit/676a6845361f615edebf1211891e6419b38ac9ea))


### Documentation

* add VERSIONING.md with @dev/[@main](https://github.com/main) pin decision ([#24](https://github.com/spark-match/spark-match-01-devops/issues/24)) ([d78d2dd](https://github.com/spark-match/spark-match-01-devops/commit/d78d2ddda1a97108fd4aa80e30052342fde31340))
* batch fixes — broken links, outdated counts, wrong versions, unverified PR refs ([#175](https://github.com/spark-match/spark-match-01-devops/issues/175)) ([9d43254](https://github.com/spark-match/spark-match-01-devops/commit/9d43254c06b41517998b35f740b29d3b6cd999b0))
* **community:** add PR and issue templates ([#130](https://github.com/spark-match/spark-match-01-devops/issues/130)) ([8dc1f62](https://github.com/spark-match/spark-match-01-devops/commit/8dc1f628e43f7fb881b87cd6d5a9a1025111f32e))
* **community:** add SECURITY.md, CONTRIBUTING.md, and CODE_OF_CONDUCT.md ([#129](https://github.com/spark-match/spark-match-01-devops/issues/129)) ([b320aeb](https://github.com/spark-match/spark-match-01-devops/commit/b320aeb92aacda0c4200d94648079d5f545a33ec))
* **docs:** redesign agents-md section 1 - purpose and structure ([#213](https://github.com/spark-match/spark-match-01-devops/issues/213)) ([d2c5795](https://github.com/spark-match/spark-match-01-devops/commit/d2c5795c87cdf2b76a0d04dcb95ab72affac94fd))
* document CI lint/security checks ([#4](https://github.com/spark-match/spark-match-01-devops/issues/4)) ([e234275](https://github.com/spark-match/spark-match-01-devops/commit/e2342754d9626ea4fb507d82f43dfe9bab27eb95))
* document commitlint-main requirement and rest-api merge pitfall ([#278](https://github.com/spark-match/spark-match-01-devops/issues/278)) ([0a1be13](https://github.com/spark-match/spark-match-01-devops/commit/0a1be132513beb293fc13ec62cac0899eff5dd4c))
* **examples:** add caller-minimal examples directory ([#133](https://github.com/spark-match/spark-match-01-devops/issues/133)) ([7d0c4fe](https://github.com/spark-match/spark-match-01-devops/commit/7d0c4fe4a19df3f21166623046c5748d304e8219))
* **governance:** add governance standard reference ([#114](https://github.com/spark-match/spark-match-01-devops/issues/114)) ([774387e](https://github.com/spark-match/spark-match-01-devops/commit/774387e0be89259e85737a187e7715f3675f96e9))
* **governance:** update bypasses.md with PR [#13](https://github.com/spark-match/spark-match-01-devops/issues/13) and [#14](https://github.com/spark-match/spark-match-01-devops/issues/14) ([#15](https://github.com/spark-match/spark-match-01-devops/issues/15)) ([c3b7d0b](https://github.com/spark-match/spark-match-01-devops/commit/c3b7d0be69b6b5d13c4d08df7c6d8239b92a95a7))
* **governance:** update bypasses.md with PRs [#9](https://github.com/spark-match/spark-match-01-devops/issues/9), [#10](https://github.com/spark-match/spark-match-01-devops/issues/10), [#11](https://github.com/spark-match/spark-match-01-devops/issues/11) ([#12](https://github.com/spark-match/spark-match-01-devops/issues/12)) ([985bec9](https://github.com/spark-match/spark-match-01-devops/commit/985bec92587a2e3de3decb75e802e03edd6763d3))
* **governance:** update status snapshot post CODEOWNERS migration ([#116](https://github.com/spark-match/spark-match-01-devops/issues/116)) ([9aee4c3](https://github.com/spark-match/spark-match-01-devops/commit/9aee4c3d44e44cd8da4cd5da13a6442de5a88927))
* **readme:** add Quick start, composite actions, governance, testing, and CACHE rate limits ([#126](https://github.com/spark-match/spark-match-01-devops/issues/126)) ([f6864ae](https://github.com/spark-match/spark-match-01-devops/commit/f6864aeadafc88d8610f8d6a143b7fe9892a311b))
* **readme:** align with post-sprint state ([#138](https://github.com/spark-match/spark-match-01-devops/issues/138)) ([e32a417](https://github.com/spark-match/spark-match-01-devops/commit/e32a417f96dbb3f8b355602fee05471a71573ef4))
* **readme:** sync README with current repo state ([#90](https://github.com/spark-match/spark-match-01-devops/issues/90)) ([de43466](https://github.com/spark-match/spark-match-01-devops/commit/de4346609a5235c42b5d261446c4ff76c4282084))
* refresh stale gitleaks v1 pin, versioning notes, and forked-workaround comments ([#50](https://github.com/spark-match/spark-match-01-devops/issues/50)) ([db0cb70](https://github.com/spark-match/spark-match-01-devops/commit/db0cb70c5c4b48e5c7c2c84b6ba7ef201cb0cc32))
* **repo:** refresh §11 catalog state and document reusable pattern ([#258](https://github.com/spark-match/spark-match-01-devops/issues/258)) ([180c4f2](https://github.com/spark-match/spark-match-01-devops/commit/180c4f2d3e448c3a9dea0e09618d10bdfcc6bce1))
* **repo:** refresh catalog state and document reusable pattern. All 9 checks green. ([180c4f2](https://github.com/spark-match/spark-match-01-devops/commit/180c4f2d3e448c3a9dea0e09618d10bdfcc6bce1))
* **repo:** refresh scope table, pin example, and codeowners paths ([#251](https://github.com/spark-match/spark-match-01-devops/issues/251)) ([05b2dde](https://github.com/spark-match/spark-match-01-devops/commit/05b2dde52f4e31396f32b100507ae79f2c135333))
* retire `[@dev](https://github.com/dev)` references in workflow headers and README ([#107](https://github.com/spark-match/spark-match-01-devops/issues/107)) ([6f853f5](https://github.com/spark-match/spark-match-01-devops/commit/6f853f5f680f267e18d54041d8789f22bc941c6f))
* **sbom-release:** clarify workflow_dispatch usage in header ([#187](https://github.com/spark-match/spark-match-01-devops/issues/187)) ([521821b](https://github.com/spark-match/spark-match-01-devops/commit/521821b9bbb47a827ccf24e9697026f296d05b5a))
* **scripts:** remove reference to governance/bypasses.md ([#18](https://github.com/spark-match/spark-match-01-devops/issues/18)) ([01c1d7d](https://github.com/spark-match/spark-match-01-devops/commit/01c1d7dc79baab610eb301b312f52eab2a2d899f))
* **security:** document current security posture + secret-scanning ([e223b4b](https://github.com/spark-match/spark-match-01-devops/commit/e223b4ba6370d7a026f113d3d246427d6f3d92a6))
* **security:** document current security posture + secret-scanning limitation ([#158](https://github.com/spark-match/spark-match-01-devops/issues/158)) ([e223b4b](https://github.com/spark-match/spark-match-01-devops/commit/e223b4ba6370d7a026f113d3d246427d6f3d92a6))
* **spark-match:** CACHE convention v4 + VERSIONING catalog v4 ([#70](https://github.com/spark-match/spark-match-01-devops/issues/70)) ([e8c213a](https://github.com/spark-match/spark-match-01-devops/commit/e8c213a5848f37a0adf4e0641b846d56c58c6634))
* **versioning:** fix typo (canonica → canónica) ([#196](https://github.com/spark-match/spark-match-01-devops/issues/196)) ([bcdd5da](https://github.com/spark-match/spark-match-01-devops/commit/bcdd5da2f8d38b67389ae8c31b31448191a8b059))


### CI/CD

* **actionlint:** fail loud on download failure + pin VERSION explicitly ([#166](https://github.com/spark-match/spark-match-01-devops/issues/166)) ([532dc07](https://github.com/spark-match/spark-match-01-devops/commit/532dc070ad8edc0b4c16cd381eddd8447c6d5d88))
* bump marocchino/sticky-pull-request-comment from 2 to 3 in the marocchino group across 1 directory ([#86](https://github.com/spark-match/spark-match-01-devops/issues/86)) ([4bd8fdc](https://github.com/spark-match/spark-match-01-devops/commit/4bd8fdc7636dbdb7853f9e4ab2be2dfe83ee4557))
* bump the github-actions group with 4 updates ([#46](https://github.com/spark-match/spark-match-01-devops/issues/46)) ([ddbed66](https://github.com/spark-match/spark-match-01-devops/commit/ddbed668c9e849b78462e3db0d20e1b99631466b))
* **ci:** add codeql config to exclude unpinned-3rd-party-action query ([#211](https://github.com/spark-match/spark-match-01-devops/issues/211)) ([f3f78c5](https://github.com/spark-match/spark-match-01-devops/commit/f3f78c5e5aefc177eaad73b0abdc4d6adf54e74c))
* **ci:** include scripts/ + tests/ + governance/ in pull_request path filter ([#167](https://github.com/spark-match/spark-match-01-devops/issues/167)) ([43dc3f2](https://github.com/spark-match/spark-match-01-devops/commit/43dc3f27b1de86333920908338d3c36c49ceabd8))
* **codeql:** cap setup job at timeout-minutes: 5 ([#164](https://github.com/spark-match/spark-match-01-devops/issues/164)) ([e91fa27](https://github.com/spark-match/spark-match-01-devops/commit/e91fa2714035d591a603622e974e405bd6fb4e5e))
* **composite:** SPDX headers on action.yml + README per action directory ([#165](https://github.com/spark-match/spark-match-01-devops/issues/165)) ([640aad4](https://github.com/spark-match/spark-match-01-devops/commit/640aad42d969506b6c5586eacff3e85c3518d0ec))
* **container-deploy-ecr:** flip provenance+sbom defaults to true for SLSA Build L3 ([#179](https://github.com/spark-match/spark-match-01-devops/issues/179)) ([7469dde](https://github.com/spark-match/spark-match-01-devops/commit/7469dde13847a417c52acabb7745585b6a8f9535))
* **container-deploy-ecr:** opt-in cosign keyless signing per tag ([#182](https://github.com/spark-match/spark-match-01-devops/issues/182)) ([3326f17](https://github.com/spark-match/spark-match-01-devops/commit/3326f170bc7c01767b82f676a1c7e17198b8e154))
* **dependabot:** tighten config — vulnerability-alerts + auto-merge patch-only ([#189](https://github.com/spark-match/spark-match-01-devops/issues/189)) ([1391d9d](https://github.com/spark-match/spark-match-01-devops/commit/1391d9d454d0653886ce0eebb39422c05513278b))
* **deps:** bump anchore/sbom-action from 0.17.7 to 0.24.0 in the third-party-actions group across 1 directory ([#237](https://github.com/spark-match/spark-match-01-devops/issues/237)) ([bd0f026](https://github.com/spark-match/spark-match-01-devops/commit/bd0f02632f953d70c03710432f429a9d1d818023))
* **deps:** bump aws-actions/configure-aws-credentials from 4 to 6 in the aws-actions group across 1 directory ([#235](https://github.com/spark-match/spark-match-01-devops/issues/235)) ([69b7195](https://github.com/spark-match/spark-match-01-devops/commit/69b7195d6b07f97dd59b323bdd24fa3a851e4aa2))
* **deps:** bump googleapis/release-please-action from 4 to 5 in the release-tools group ([#136](https://github.com/spark-match/spark-match-01-devops/issues/136)) ([f21b4d7](https://github.com/spark-match/spark-match-01-devops/commit/f21b4d7ceb2d76f5399e62647031e601a23cd485))
* **deps:** bump the actions-ecosystem group across 1 directory with 3 updates ([#239](https://github.com/spark-match/spark-match-01-devops/issues/239)) ([3c615cd](https://github.com/spark-match/spark-match-01-devops/commit/3c615cd4e86bed92353ce7e7bd996d0c670843e6))
* **deps:** bump the actions-ecosystem group with 3 updates ([#135](https://github.com/spark-match/spark-match-01-devops/issues/135)) ([13edf19](https://github.com/spark-match/spark-match-01-devops/commit/13edf1999395c427ca3335530530ab1fb4fe361a))
* **ecosystem:** add trivy reusable workflow (fs/image/config scan) ([#181](https://github.com/spark-match/spark-match-01-devops/issues/181)) ([9ce7f38](https://github.com/spark-match/spark-match-01-devops/commit/9ce7f380be09c298ae14990cc4b0469ff102160f))
* **governance:** verify CODEOWNERS + ruleset enforcement ([#190](https://github.com/spark-match/spark-match-01-devops/issues/190)) ([c212cd3](https://github.com/spark-match/spark-match-01-devops/commit/c212cd3e19b2af30900e045773ee86bf86068475))
* **release:** attach CycloneDX SBOM to GitHub Release on release:published ([#186](https://github.com/spark-match/spark-match-01-devops/issues/186)) ([6bd9c0f](https://github.com/spark-match/spark-match-01-devops/commit/6bd9c0fc66d120c34c29e278d56986b959731f42))
* **s bom:** rename sbom-release.yml to sbom.yml (force GH Actions re-registration) ([#188](https://github.com/spark-match/spark-match-01-devops/issues/188)) ([07d6c0d](https://github.com/spark-match/spark-match-01-devops/commit/07d6c0dc28f6f7787f3be5bf13cf29801fd5bad8))
* **secrets:** add .gitleaks.toml + pre-commit hook + SECURITY.md upgrade ([#191](https://github.com/spark-match/spark-match-01-devops/issues/191)) ([ddb7aae](https://github.com/spark-match/spark-match-01-devops/commit/ddb7aae816a73404f780ab2646b95d46b71cf6b0))
* test push trigger (trivial v2) ([66df562](https://github.com/spark-match/spark-match-01-devops/commit/66df5620cd1fbb229b018efb4dd6e420a191586a))
* trigger rerun ([ab3165f](https://github.com/spark-match/spark-match-01-devops/commit/ab3165fab9310bcea50016f3a73ebac4d6a129a5))
* trigger rerun ([210bcf8](https://github.com/spark-match/spark-match-01-devops/commit/210bcf87170d023f987760f23fad82c2f0b52b3c))
* trigger self-test on direct pushes to main/dev (strict mode) ([#51](https://github.com/spark-match/spark-match-01-devops/issues/51)) ([5857588](https://github.com/spark-match/spark-match-01-devops/commit/5857588f94855d1fe35024b516b63a50ce588f9b))


### Tests

* **composite-actions:** add bats tests for validate-workflow-inputs and run-pytest-with-args ([#125](https://github.com/spark-match/spark-match-01-devops/issues/125)) ([8f8719e](https://github.com/spark-match/spark-match-01-devops/commit/8f8719e601983f0ae487e97c90dfa0584fa5e74c))
* **lambda-permission:** add pytest suite for check_lambda_permission_source_arn.py ([#124](https://github.com/spark-match/spark-match-01-devops/issues/124)) ([db9af9a](https://github.com/spark-match/spark-match-01-devops/commit/db9af9a7d63b55cc36daea0d0e890eddf4ac02d2))
* **quality:** add multi-offender SAM fixture + scan tests/bats/helpers ([#178](https://github.com/spark-match/spark-match-01-devops/issues/178)) ([800b4b7](https://github.com/spark-match/spark-match-01-devops/commit/800b4b7cc3e7e00d0a339500f096770f590f9d49))
* **reconciler:** add bats suite for configure-repo-rulesets.sh ([#128](https://github.com/spark-match/spark-match-01-devops/issues/128)) ([c6d4208](https://github.com/spark-match/spark-match-01-devops/commit/c6d4208561ed61cb8afd564f310810e9e8df176b))

## [1.0.2](https://github.com/spark-match/spark-match-01-devops/compare/v1.0.1...v1.0.2) (2026-08-04)


### Bug Fixes

* **governance:** require commitlint-main check to gate squash merges ([#276](https://github.com/spark-match/spark-match-01-devops/issues/276)) ([0955132](https://github.com/spark-match/spark-match-01-devops/commit/09551327a246653bdc5fcc357b65fb2fd5ade926))


### Documentation

* document commitlint-main requirement and rest-api merge pitfall ([#278](https://github.com/spark-match/spark-match-01-devops/issues/278)) ([0624417](https://github.com/spark-match/spark-match-01-devops/commit/0624417b5a6d0b34c8855018c0d7fd9b1930096b))

## [1.0.1](https://github.com/spark-match/spark-match-01-devops/compare/v1.0.0...v1.0.1) (2026-08-04)


### Bug Fixes

* **governance:** reconcile 02-infrastructure status-checks vs reported ([7913515](https://github.com/spark-match/spark-match-01-devops/commit/7913515d0b2c24cc3f3b5f8189dc2428262d7876))
* **governance:** reconcile 02-infrastructure statusChecks vs reported contexts ([#274](https://github.com/spark-match/spark-match-01-devops/issues/274)) ([7913515](https://github.com/spark-match/spark-match-01-devops/commit/7913515d0b2c24cc3f3b5f8189dc2428262d7876))

## [1.0.0](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.18...v1.0.0) (2026-08-04)


### ⚠ BREAKING CHANGES

* AGENTS.md v1 contract.
* refresh agents.md for v1.0.0 release. All checks green. Documents REST API workaround for EMU accounts in section 4.4. Merged via REST API direct.
* refresh agents.md for v1.0.0 release ([#264](https://github.com/spark-match/spark-match-01-devops/issues/264))

### Features

* refresh agents.md for v1.0.0 release ([#264](https://github.com/spark-match/spark-match-01-devops/issues/264)) ([b1bbd59](https://github.com/spark-match/spark-match-01-devops/commit/b1bbd593942640554a73d0b1e54a49b70514ba38))
* refresh agents.md for v1.0.0 release ([#271](https://github.com/spark-match/spark-match-01-devops/issues/271)) ([bed75ea](https://github.com/spark-match/spark-match-01-devops/commit/bed75ea240c9f5cd5181547af943efee41de6974))
* refresh agents.md for v1.0.0 release. All checks green. Documents REST API workaround for EMU accounts in section 4.4. Merged via REST API direct. ([b1bbd59](https://github.com/spark-match/spark-match-01-devops/commit/b1bbd593942640554a73d0b1e54a49b70514ba38))


### Bug Fixes

* **governance:** align status check names with reported job names ([0e73e2e](https://github.com/spark-match/spark-match-01-devops/commit/0e73e2e46791cfb82c41c5f65a887741ad526b0c))
* **governance:** align status check names with reported job names ([#273](https://github.com/spark-match/spark-match-01-devops/issues/273)) ([0e73e2e](https://github.com/spark-match/spark-match-01-devops/commit/0e73e2e46791cfb82c41c5f65a887741ad526b0c))
* **quality:** allow x.y.z major &gt;=1 in release-please manifest bats regex ([dbbbe82](https://github.com/spark-match/spark-match-01-devops/commit/dbbbe824e136e44737d1f58d81d9c245e1687ac5))
* **quality:** allow x.y.z major &gt;=1 in release-please manifest bats regex ([#266](https://github.com/spark-match/spark-match-01-devops/issues/266)) ([20d4582](https://github.com/spark-match/spark-match-01-devops/commit/20d45827f4afa6d1b87bc8bbd90f6687151c17ec))
* **quality:** allow x.y.z major &gt;=1 in release-please manifest bats regex ([#272](https://github.com/spark-match/spark-match-01-devops/issues/272)) ([dbbbe82](https://github.com/spark-match/spark-match-01-devops/commit/dbbbe824e136e44737d1f58d81d9c245e1687ac5))
* **quality:** allow x.y.z major &gt;=1 in release-please manifest bats regex. All checks green. Required to merge release PR [#265](https://github.com/spark-match/spark-match-01-devops/issues/265) for v1.0.0. Merged via REST API direct. ([20d4582](https://github.com/spark-match/spark-match-01-devops/commit/20d45827f4afa6d1b87bc8bbd90f6687151c17ec))


### Reverts

* **docs:** refresh agents.md for v1.0.0 to undo pull request 264 ([552525f](https://github.com/spark-match/spark-match-01-devops/commit/552525f45b2bc89c15fdb98944dc754f1f74f947))
* **docs:** refresh agents.md for v1.0.0 to undo pull request 264 ([#270](https://github.com/spark-match/spark-match-01-devops/issues/270)) ([552525f](https://github.com/spark-match/spark-match-01-devops/commit/552525f45b2bc89c15fdb98944dc754f1f74f947))
* **quality:** bats regex v1 allow to undo pull request 266 ([f22ccaa](https://github.com/spark-match/spark-match-01-devops/commit/f22ccaaca9bce0cc4ccb38a891fabcb9ca1620f5))
* **quality:** bats regex v1 allow to undo pull request 266 ([#269](https://github.com/spark-match/spark-match-01-devops/issues/269)) ([f22ccaa](https://github.com/spark-match/spark-match-01-devops/commit/f22ccaaca9bce0cc4ccb38a891fabcb9ca1620f5))
* **repo:** release 1.0.0 to undo pull request 265 ([3948a80](https://github.com/spark-match/spark-match-01-devops/commit/3948a80135ea0a8646c0f21cd0848b4149ff95a4))
* **repo:** release 1.0.0 to undo pull request 265 ([#267](https://github.com/spark-match/spark-match-01-devops/issues/267)) ([3948a80](https://github.com/spark-match/spark-match-01-devops/commit/3948a80135ea0a8646c0f21cd0848b4149ff95a4))

## [0.1.18](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.17...v0.1.18) (2026-08-03)


### Bug Fixes

* **repo:** split sbom generation from release upload (anchore v0.24.0 regression) ([#260](https://github.com/spark-match/spark-match-01-devops/issues/260)) ([cc96f19](https://github.com/spark-match/spark-match-01-devops/commit/cc96f196e83b5e28f67368bf9362e620d1c7eccc))
* **repo:** split sbom generation from release upload (anchore v0.24.0 regression). All 9 checks green. Merged via REST API direct. ([cc96f19](https://github.com/spark-match/spark-match-01-devops/commit/cc96f196e83b5e28f67368bf9362e620d1c7eccc))
* **workflows:** simplify reusable-terraform-plan env binding to single input ([#262](https://github.com/spark-match/spark-match-01-devops/issues/262)) ([1dc78c0](https://github.com/spark-match/spark-match-01-devops/commit/1dc78c0209ad3ba611f2edc2a4eac62393a44641))

## [0.1.17](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.16...v0.1.17) (2026-08-03)


### Documentation

* **repo:** refresh §11 catalog state and document reusable pattern ([#258](https://github.com/spark-match/spark-match-01-devops/issues/258)) ([180c4f2](https://github.com/spark-match/spark-match-01-devops/commit/180c4f2d3e448c3a9dea0e09618d10bdfcc6bce1))
* **repo:** refresh catalog state and document reusable pattern. All 9 checks green. ([180c4f2](https://github.com/spark-match/spark-match-01-devops/commit/180c4f2d3e448c3a9dea0e09618d10bdfcc6bce1))

## [0.1.16](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.15...v0.1.16) (2026-08-03)


### Features

* **workflows:** extract commitlint + release-please into shared reusables ([#254](https://github.com/spark-match/spark-match-01-devops/issues/254)) ([e7618a7](https://github.com/spark-match/spark-match-01-devops/commit/e7618a71e995d7da2bdcd9eb641f897fe2ea6f89))


### Bug Fixes

* **workflows:** pass release-please secrets via workflow_call secrets block ([#256](https://github.com/spark-match/spark-match-01-devops/issues/256)) ([800177d](https://github.com/spark-match/spark-match-01-devops/commit/800177d4dcce149dc95a0769dbf62185f70574a9))
* **workflows:** remove concurrency blocks from reusable ci workflows ([#255](https://github.com/spark-match/spark-match-01-devops/issues/255)) ([32f8e0d](https://github.com/spark-match/spark-match-01-devops/commit/32f8e0d651caa3aead979bb9ccf87a5c5860aa21))

## [0.1.15](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.14...v0.1.15) (2026-08-03)


### Bug Fixes

* **repo:** align commit-msg hook with header-max-length ci rule ([#253](https://github.com/spark-match/spark-match-01-devops/issues/253)) ([5405471](https://github.com/spark-match/spark-match-01-devops/commit/5405471ea88709ba8c87cd25e5e24cd2f06c38e2))


### Documentation

* **repo:** refresh scope table, pin example, and codeowners paths ([#251](https://github.com/spark-match/spark-match-01-devops/issues/251)) ([05b2dde](https://github.com/spark-match/spark-match-01-devops/commit/05b2dde52f4e31396f32b100507ae79f2c135333))

## [0.1.14](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.13...v0.1.14) (2026-08-03)


### Bug Fixes

* **composite:** kebab-case name and align step ids with step names ([#248](https://github.com/spark-match/spark-match-01-devops/issues/248)) ([df58942](https://github.com/spark-match/spark-match-01-devops/commit/df58942e45e3af36fb5ffa1a62181927a9cefc50))

## [0.1.13](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.12...v0.1.13) (2026-08-03)


### Bug Fixes

* **ci:** allow deps scope in commitlint (dependabot) ([#247](https://github.com/spark-match/spark-match-01-devops/issues/247)) ([40e8361](https://github.com/spark-match/spark-match-01-devops/commit/40e836122960a22c41f213df41baa408266d68c9))
* **ci:** disable body-max-line-length so dependabot bumps pass ([#244](https://github.com/spark-match/spark-match-01-devops/issues/244)) ([98243cd](https://github.com/spark-match/spark-match-01-devops/commit/98243cd54e0d4a7dd6ced9a7a1946032c3d7bd8e))
* **ci:** disable body-max-line-length so dependabot bumps pass ([#246](https://github.com/spark-match/spark-match-01-devops/issues/246)) ([47baeff](https://github.com/spark-match/spark-match-01-devops/commit/47baeffd7520f52fb304cf810b44082baa77aa93))


### CI/CD

* **deps:** bump anchore/sbom-action from 0.17.7 to 0.24.0 in the third-party-actions group across 1 directory ([#237](https://github.com/spark-match/spark-match-01-devops/issues/237)) ([bd0f026](https://github.com/spark-match/spark-match-01-devops/commit/bd0f02632f953d70c03710432f429a9d1d818023))
* **deps:** bump aws-actions/configure-aws-credentials from 4 to 6 in the aws-actions group across 1 directory ([#235](https://github.com/spark-match/spark-match-01-devops/issues/235)) ([69b7195](https://github.com/spark-match/spark-match-01-devops/commit/69b7195d6b07f97dd59b323bdd24fa3a851e4aa2))
* **deps:** bump the actions-ecosystem group across 1 directory with 3 updates ([#239](https://github.com/spark-match/spark-match-01-devops/issues/239)) ([3c615cd](https://github.com/spark-match/spark-match-01-devops/commit/3c615cd4e86bed92353ce7e7bd996d0c670843e6))

## [0.1.12](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.11...v0.1.12) (2026-08-03)


### Features

* **workflows:** real pnpm/yarn/bun support across node reusables ([#226](https://github.com/spark-match/spark-match-01-devops/issues/226)) ([df4e515](https://github.com/spark-match/spark-match-01-devops/commit/df4e515cb8becf063ceed9eac3ca3dc3685037eb))


### Bug Fixes

* **workflows:** accept apply-role-arn as string input (mirror plan) ([#242](https://github.com/spark-match/spark-match-01-devops/issues/242)) ([079fb17](https://github.com/spark-match/spark-match-01-devops/commit/079fb17bfba017e62ffc5679a74d21d7e17ddb83))
* **workflows:** accept plan-role-arn as string input to bypass cross-owner secret masking ([#241](https://github.com/spark-match/spark-match-01-devops/issues/241)) ([46f4989](https://github.com/spark-match/spark-match-01-devops/commit/46f49890a977a9294799448f9061d13924528a28))
* **workflows:** add hex16 diag to bypass log masking of role arn ([#240](https://github.com/spark-match/spark-match-01-devops/issues/240)) ([79336de](https://github.com/spark-match/spark-match-01-devops/commit/79336dee63f0ec87c7bae31c6f92e4ee78608d2c))
* **workflows:** bind reusable-terraform-plan job to gh environment ([#228](https://github.com/spark-match/spark-match-01-devops/issues/228)) ([82f8da0](https://github.com/spark-match/spark-match-01-devops/commit/82f8da0cf8becc713d2c4bc8b4c85375a486ccc3))
* **workflows:** detect role arn format in diag step (plan only) ([#238](https://github.com/spark-match/spark-match-01-devops/issues/238)) ([3aa4e0c](https://github.com/spark-match/spark-match-01-devops/commit/3aa4e0c51ae3e123d8620e3f89b7eae963b67ca8))
* **workflows:** look up aws role arn via plan/apply-role-arn-secret input ([#232](https://github.com/spark-match/spark-match-01-devops/issues/232)) ([29ab3ad](https://github.com/spark-match/spark-match-01-devops/commit/29ab3add8b0365260797e9ad26148424fd25372b))
* **workflows:** make aws role arn secrets optional ([#243](https://github.com/spark-match/spark-match-01-devops/issues/243)) ([320c799](https://github.com/spark-match/spark-match-01-devops/commit/320c7993cfeb6b0be73dac0970b5582b6d77b4d1))
* **workflows:** make aws role arn secrets optional for env-scoped lookup ([#229](https://github.com/spark-match/spark-match-01-devops/issues/229)) ([9887618](https://github.com/spark-match/spark-match-01-devops/commit/98876188c5d64ece652f9eac5b163cd86b9dcd91))
* **workflows:** remove aws role arn secrets decl; rely on env binding ([#231](https://github.com/spark-match/spark-match-01-devops/issues/231)) ([69f4d97](https://github.com/spark-match/spark-match-01-devops/commit/69f4d97ec7f8be6a78e645e9f51bcf944852ace0))
* **workflows:** revert dynamic secret lookup; restore standard cross-owner pattern ([#234](https://github.com/spark-match/spark-match-01-devops/issues/234)) ([d9a6fca](https://github.com/spark-match/spark-match-01-devops/commit/d9a6fcaf9ca1861590e387c2b48bf6a0e81b8d18))

## [0.1.11](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.10...v0.1.11) (2026-08-02)


### Bug Fixes

* **ci:** skip commitlint on push when head commit is a release ([#222](https://github.com/spark-match/spark-match-01-devops/issues/222)) ([5cc015b](https://github.com/spark-match/spark-match-01-devops/commit/5cc015bfb553aceb7b74a9283ecb175f1cab9cdf))

## [0.1.10](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.9...v0.1.10) (2026-08-02)


### Features

* **composite:** extract bats-runner from reusable-quality.yml ([#220](https://github.com/spark-match/spark-match-01-devops/issues/220)) ([e234adf](https://github.com/spark-match/spark-match-01-devops/commit/e234adf81c5798ab598afc7b79ccea3997ecdbe5))

## [0.1.9](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.8...v0.1.9) (2026-08-02)


### Bug Fixes

* **ci:** commitlint commit-depth=2 + short merge body template ([#216](https://github.com/spark-match/spark-match-01-devops/issues/216)) ([03c9ba9](https://github.com/spark-match/spark-match-01-devops/commit/03c9ba93ed4ce6d7b7fc326bf197ff78d4cd1e41))

## [0.1.8](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.7...v0.1.8) (2026-08-02)


### Bug Fixes

* **ci:** skip commitlint for release-please branches ([#214](https://github.com/spark-match/spark-match-01-devops/issues/214)) ([befbb4b](https://github.com/spark-match/spark-match-01-devops/commit/befbb4b58f130c68ce2f04f38c1750a599103e6c))


### Documentation

* **docs:** redesign agents-md section 1 - purpose and structure ([#213](https://github.com/spark-match/spark-match-01-devops/issues/213)) ([d2c5795](https://github.com/spark-match/spark-match-01-devops/commit/d2c5795c87cdf2b76a0d04dcb95ab72affac94fd))


### CI/CD

* **ci:** add codeql config to exclude unpinned-3rd-party-action query ([#211](https://github.com/spark-match/spark-match-01-devops/issues/211)) ([f3f78c5](https://github.com/spark-match/spark-match-01-devops/commit/f3f78c5e5aefc177eaad73b0abdc4d6adf54e74c))

## [0.1.7](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.6...v0.1.7) (2026-07-30)


### Bug Fixes

* **sbom:** download SBOM artifact for verify step + drop redundant gh release upload ([#198](https://github.com/spark-match/spark-match-01-devops/issues/198)) ([900b70f](https://github.com/spark-match/spark-match-01-devops/commit/900b70f317ac26c45384a884c9c58362f04d4452))

## [0.1.6](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.5...v0.1.6) (2026-07-30)


### Documentation

* **versioning:** fix typo (canonica → canónica) ([#196](https://github.com/spark-match/spark-match-01-devops/issues/196)) ([bcdd5da](https://github.com/spark-match/spark-match-01-devops/commit/bcdd5da2f8d38b67389ae8c31b31448191a8b059))

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

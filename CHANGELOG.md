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

## [0.2.0](https://github.com/spark-match/spark-match-01-devops/compare/v0.1.0...v0.2.0) (2026-07-29)


### Added

* **ci:** add CHANGELOG.md and release-please automation ([#131](https://github.com/spark-match/spark-match-01-devops/issues/131)) ([1741385](https://github.com/spark-match/spark-match-01-devops/commit/17413854a5651af2df9af6db3d97647a6fb10ce5))
* **ci:** add CI lint checks (actionlint + gitleaks + yamllint) ([#3](https://github.com/spark-match/spark-match-01-devops/issues/3)) ([7cb5a92](https://github.com/spark-match/spark-match-01-devops/commit/7cb5a92aca2903699d0e811ddf5a8fc4cd06712a))
* **ci:** add explicit input validation to terraform-plan reusable ([#25](https://github.com/spark-match/spark-match-01-devops/issues/25)) ([3f91cf8](https://github.com/spark-match/spark-match-01-devops/commit/3f91cf861475eb1c08e2a0718119ef448b4af1a9))
* **ci:** composite actions + refactor 20 reusable workflows ([#102](https://github.com/spark-match/spark-match-01-devops/issues/102)) ([08c2749](https://github.com/spark-match/spark-match-01-devops/commit/08c27495fd5ba635d79f72a3aeeb7a779e159bb5))
* **ci:** make terraform reusables N-environment aware ([#7](https://github.com/spark-match/spark-match-01-devops/issues/7)) ([f759f3e](https://github.com/spark-match/spark-match-01-devops/commit/f759f3e510ab1cb4c410d9e1b07318100b443b1d))
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
* reusable workflows for terraform + latex ([#1](https://github.com/spark-match/spark-match-01-devops/issues/1)) ([6478e1e](https://github.com/spark-match/spark-match-01-devops/commit/6478e1ef496aa45833424772a1d2c615acb5f432))
* **reusables:** cache key convention v4 (pkgmanager + env + lowercase) ([#62](https://github.com/spark-match/spark-match-01-devops/issues/62)) ([3e30cdc](https://github.com/spark-match/spark-match-01-devops/commit/3e30cdc11a81c5e3a8eab9d43589d8a58521956f))
* **reusables:** per-env npm cache + working-directory input ([#55](https://github.com/spark-match/spark-match-01-devops/issues/55)) ([d5b4f79](https://github.com/spark-match/spark-match-01-devops/commit/d5b4f79dda4a35008f25b0b08ed075b1695b4ac3))
* **scripts:** add configure-merge-methods.sh ([#5](https://github.com/spark-match/spark-match-01-devops/issues/5)) ([05f23e0](https://github.com/spark-match/spark-match-01-devops/commit/05f23e089c89cc4dbaa2e23d6bb320ddf3af65b8))
* **scripts:** add configure-repo-rulesets.sh ([#11](https://github.com/spark-match/spark-match-01-devops/issues/11)) ([0398a13](https://github.com/spark-match/spark-match-01-devops/commit/0398a13f9cdc1851e220cd596af708d9d22ed414))
* **scripts:** add create-pr helper (ps1 + sh) to avoid JSON body malformation ([#26](https://github.com/spark-match/spark-match-01-devops/issues/26)) ([5d5c939](https://github.com/spark-match/spark-match-01-devops/commit/5d5c939284c567c9b9f2aaa35acb2a3ac2b31c1c))
* **scripts:** add OrganizationAdmin bypass_actors to rulesets ([#14](https://github.com/spark-match/spark-match-01-devops/issues/14)) ([2f090a5](https://github.com/spark-match/spark-match-01-devops/commit/2f090a5e128cbb0341730527abf8c2130501dfbe))
* **scripts:** ruleset with full pull_request rule coverage ([#13](https://github.com/spark-match/spark-match-01-devops/issues/13)) ([b70bb8e](https://github.com/spark-match/spark-match-01-devops/commit/b70bb8ea66274eab94c576a47ffdb7b5d54412d0))


### Fixed

* **actions:** invoke composite scripts via explicit bash ([b1c47e5](https://github.com/spark-match/spark-match-01-devops/commit/b1c47e59b36c03cfefaa85785ee80721df3063d6))
* **cfn-nag:** drop --config-path (not supported by cfn_nag_scan 0.8.10) ([d7e49bc](https://github.com/spark-match/spark-match-01-devops/commit/d7e49bc86c319ffc379281d4c65053aef74a4a82))
* **cfn-nag:** scan per-file to exclude .aws-sam/build/template.yaml ([#83](https://github.com/spark-match/spark-match-01-devops/issues/83)) ([19046eb](https://github.com/spark-match/spark-match-01-devops/commit/19046eb0c8a751ee5d9b408420bd24a3d388869c))
* **ci:** reference composite actions via cross-repo path ([a6d9879](https://github.com/spark-match/spark-match-01-devops/commit/a6d987981583cbb4453b57d2bfe2323b85656508))
* **ci:** restore missing `steps:` keyword in 14 recipes ([87e50a8](https://github.com/spark-match/spark-match-01-devops/commit/87e50a82e4747b8c41d876e6bb8ec9bcfcbb7da8))
* **codeowners:** add github-actions[bot] to release-please managed paths ([#140](https://github.com/spark-match/spark-match-01-devops/issues/140)) ([d1eeb16](https://github.com/spark-match/spark-match-01-devops/commit/d1eeb16079971c65503cd46f3115e3ea385e6750))
* **codeowners:** align header text with ruleset (compliance 6/6) ([#118](https://github.com/spark-match/spark-match-01-devops/issues/118)) ([2efa0bb](https://github.com/spark-match/spark-match-01-devops/commit/2efa0bbd2c36388a5e450982ec51aa5138cb13bc))
* **codeowners:** cover /docs /governance and /LICENSE in 01-devops ([#119](https://github.com/spark-match/spark-match-01-devops/issues/119)) ([2d4593e](https://github.com/spark-match/spark-match-01-devops/commit/2d4593e9ee5bbfb65b26f8122a1c9f1db112403b))
* **codeowners:** use [@github-actions](https://github.com/github-actions) (without [bot]) for release-please managed paths ([#141](https://github.com/spark-match/spark-match-01-devops/issues/141)) ([486b1a1](https://github.com/spark-match/spark-match-01-devops/commit/486b1a18b5231dba2b8c5d588fa7eeb6da10cd24))
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
* **governance:** CODE OWNERS técnicos, sin product-owners como catch-all ([cc81424](https://github.com/spark-match/spark-match-01-devops/commit/cc814246f3f2ef00d126b8c4033417a7e3d9b7f9))
* **governance:** CODEOWNERS simplificado a solo devops ([2a43e0b](https://github.com/spark-match/spark-match-01-devops/commit/2a43e0b37a74eb0adc9092fe0b23ddc5802cfdbd))
* **governance:** correct spark-match-02-infrastructure Checkov status check name ([#111](https://github.com/spark-match/spark-match-01-devops/issues/111)) ([6399df5](https://github.com/spark-match/spark-match-01-devops/commit/6399df54ab19e205020c094218a5f82e74b74e63))
* **governance:** set requireCodeOwnerReview=true and document CODEOWNERS choice ([#113](https://github.com/spark-match/spark-match-01-devops/issues/113)) ([084959c](https://github.com/spark-match/spark-match-01-devops/commit/084959c671cc039cd06a50b90924f0a957b7d07f))
* **migrations-dry-run:** drop redundant CLI forwarding, fix v9 --schema array bug ([#93](https://github.com/spark-match/spark-match-01-devops/issues/93)) ([a47a6b2](https://github.com/spark-match/spark-match-01-devops/commit/a47a6b2d98acb41ab3ebe17a39f72d4b49309b20))
* **migrations-dry-run:** restore d8b819c's drop-forwarding recipe on main ([#94](https://github.com/spark-match/spark-match-01-devops/issues/94)) ([64d8cc3](https://github.com/spark-match/spark-match-01-devops/commit/64d8cc33be96f146def08bbf5fd90f4f9ad21343))
* **python-ci:** replace IFS+here-string array with --group flag loop ([b507860](https://github.com/spark-match/spark-match-01-devops/commit/b507860beff7a009249d74fa88d2f85eb6437f6f))
* **python-ci:** replace IFS+here-string array with --group flag loop ([#75](https://github.com/spark-match/spark-match-01-devops/issues/75)) ([b507860](https://github.com/spark-match/spark-match-01-devops/commit/b507860beff7a009249d74fa88d2f85eb6437f6f))
* **python:** W1 workaround - hardcode matrix python-version (cross-owner fix) ([#74](https://github.com/spark-match/spark-match-01-devops/issues/74)) ([d68efc6](https://github.com/spark-match/spark-match-01-devops/commit/d68efc695d250dd7c12f4dde6a2a0659ca5b1867))
* **python:** W1 workaround for cross-owner matrix bug (hardcode ([d68efc6](https://github.com/spark-match/spark-match-01-devops/commit/d68efc695d250dd7c12f4dde6a2a0659ca5b1867))
* **reconciler:** strip CR from repo names and assemble JSON via jq --argjson ([#112](https://github.com/spark-match/spark-match-01-devops/issues/112)) ([6db7de8](https://github.com/spark-match/spark-match-01-devops/commit/6db7de8f9939b7457fa7973aba81cca53780553d))
* **release-please:** drop _copyright from manifest ([#139](https://github.com/spark-match/spark-match-01-devops/issues/139)) ([0fc20cc](https://github.com/spark-match/spark-match-01-devops/commit/0fc20ccca1c852fd29d84a1337bedb5609973d16))
* **sonar:** add always() to enforcement if (QG step exits 1, blocking subsequent if eval) ([8bbd580](https://github.com/spark-match/spark-match-01-devops/commit/8bbd580ef5c36f1482ab9688370aa572e1efa1cf))
* **sonar:** continue-on-error on QG step so enforcement is caller-controlled ([61245fa](https://github.com/spark-match/spark-match-01-devops/commit/61245faf80bd724cba2fcc8455ace00bbcf09a89))
* **sonar:** correct action prefix for sonarqube-quality-gate-action ([#103](https://github.com/spark-match/spark-match-01-devops/issues/103)) ([e034e98](https://github.com/spark-match/spark-match-01-devops/commit/e034e9821f44748566ff49396836598aea10da16))
* **sonar:** declare fail-on-quality-gate as string + custom enforcement step ([#105](https://github.com/spark-match/spark-match-01-devops/issues/105)) ([eb04a09](https://github.com/spark-match/spark-match-01-devops/commit/eb04a090d235c6d4c63c6e725498017b9a323beb))
* **sonar:** declare SONAR_TOKEN as required secret in recipes ([5efd4c1](https://github.com/spark-match/spark-match-01-devops/commit/5efd4c109a5b95cc239b63084a0682886d2a8854))
* **sonar:** declare SONAR_TOKEN as required secret in recipes ([#104](https://github.com/spark-match/spark-match-01-devops/issues/104)) ([5efd4c1](https://github.com/spark-match/spark-match-01-devops/commit/5efd4c109a5b95cc239b63084a0682886d2a8854))
* **sonar:** drop projectName from scanner args ([c8d7b60](https://github.com/spark-match/spark-match-01-devops/commit/c8d7b6065684828f0588e6cfb6e6dda5a8fef4d7))
* **sonar:** drop projectName from scanner args ([a43b5e3](https://github.com/spark-match/spark-match-01-devops/commit/a43b5e3e095fddf8af32a227e2b4eec3633d97f2))
* **sonar:** fail loud on QG timeout + cache scanner + skip architecture sensor ([#117](https://github.com/spark-match/spark-match-01-devops/issues/117)) ([15e2309](https://github.com/spark-match/spark-match-01-devops/commit/15e2309ff785aa7b946dcb57822011f8205609a0))
* **workflow:** replace regex_replace with shell step in latex-build ([#2](https://github.com/spark-match/spark-match-01-devops/issues/2)) ([224d28f](https://github.com/spark-match/spark-match-01-devops/commit/224d28fc8f0f445de3727a866e2657b91ce48444))
* **workflows:** remove duplicate Resolve environment identifier step ([#19](https://github.com/spark-match/spark-match-01-devops/issues/19)) ([6e25fe2](https://github.com/spark-match/spark-match-01-devops/commit/6e25fe26db8c0f3bbe6103bea2ebf5900e44f112))
* **workflows:** set working-directory on pre-checkout env step ([eb34d88](https://github.com/spark-match/spark-match-01-devops/commit/eb34d886a9a9b3462ba1e30a7d051dc8fbe8c61a))

## [0.1.0] - 2026-07-26

Initial release. Documents the catalog as of the 16-point improvement plan
sprint (see `DEVOPS-UPGRADE.md` § 15).

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

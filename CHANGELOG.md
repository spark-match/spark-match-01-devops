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

## [1.0.3](https://github.com/spark-match/spark-match-01-devops/compare/v1.0.2...v1.0.3) (2026-08-04)


### Documentation

* add post-rewrite note documenting 2026-08-04 history cleanup ([#280](https://github.com/spark-match/spark-match-01-devops/issues/280)) ([2460dbb](https://github.com/spark-match/spark-match-01-devops/commit/2460dbb8fe090c4cc0075d14ff8010431a1ddaf0))

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

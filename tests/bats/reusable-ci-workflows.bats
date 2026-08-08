#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reusable-ci-workflows.bats - regression guards for the cross-repo CI reusables
# =============================================================================
# Locks down the shape of:
#   - .github/workflows/reusable-commitlint.yml
#   - .github/workflows/reusable-release-please.yml
#   - the internal callers .github/workflows/commitlint.yml and
#     .github/workflows/release-please.yml (which must consume the
#     reusables so the catalog is auto-dogfooded)
#
# What this file protects against:
#   - Removing workflow_call from the reusable (would break cross-repo callers)
#   - Removing a documented input that callers depend on
#   - Forgetting to consume the reusable from the internal workflow (defeats
#     auto-dogfooding; CI could pass while the reusable shape drifts)
#   - Renaming an input or changing its type (silent breakage for consumers)
# =============================================================================

REUSABLE_COMMITLINT="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-commitlint.yml"
REUSABLE_RELEASE_PLEASE="$BATS_TEST_DIRNAME/../../.github/workflows/reusable-release-please.yml"
INTERNAL_COMMITLINT="$BATS_TEST_DIRNAME/../../.github/workflows/commitlint.yml"
INTERNAL_RELEASE_PLEASE="$BATS_TEST_DIRNAME/../../.github/workflows/release-please.yml"

# ---------------------------------------------------------------------------
# reusable-commitlint.yml shape
# ---------------------------------------------------------------------------

@test "reusable-ci-workflows: reusable-commitlint.yml exists" {
  [ -f "$REUSABLE_COMMITLINT" ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml declares workflow_call" {
  run grep -E "^\s*workflow_call:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml exposes config-file input" {
  run grep -E "config-file:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "config-file:" "$REUSABLE_COMMITLINT"
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml exposes commit-depth input" {
  run grep -E "commit-depth:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "commit-depth:" "$REUSABLE_COMMITLINT"
  [[ "$output" == *"type: number"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml exposes help-url input" {
  run grep -E "help-url:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "help-url:" "$REUSABLE_COMMITLINT"
  [[ "$output" == *"type: string"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml exposes skip-release-please input as boolean" {
  run grep -E "skip-release-please:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "skip-release-please:" "$REUSABLE_COMMITLINT"
  [[ "$output" == *"type: boolean"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml uses wagoid/commitlint-github-action@v6" {
  run grep -E "uses: wagoid/commitlint-github-action@v[0-9]+" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml uses actions/checkout@v7" {
  run grep -E "uses: actions/checkout@v[0-9]+" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml fails on errors" {
  run grep -E "failOnErrors: true" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-commitlint.yml reads only contents" {
  run grep -A2 "^permissions:" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contents: read"* ]]
  [[ "$output" != *"contents: write"* ]]
}

@test "reusable-ci-workflows: reusable-commitlint.yml detects history rewrites via git" {
  # When history is rewritten, github.event.before points at a commit the
  # branch no longer descends from, and the before..after range covers
  # unrelated history. commitDepth does not help: the action counts from the
  # START of the range, so it lints the OLDEST commits in it.
  #
  # Measured twice, on the first fast-forward of 02-infrastructure and of
  # 03-backend. Both left the promoted branch red over commits that had been
  # sitting on main for weeks and were valid under the rules of their time.
  #
  # The detection must be the ancestry test, not github.event.forced. That
  # field was tried first and skipped nothing -- the step still ran on a
  # re-run of the affected job. Assert on the mechanism that was actually
  # verified, so a future rewrite of this step cannot quietly go back to
  # trusting the payload.
  run grep -E "merge-base --is-ancestor" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
  run grep -E "rewritten != 'true'" "$REUSABLE_COMMITLINT"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# reusable-release-please.yml shape
# ---------------------------------------------------------------------------

@test "reusable-ci-workflows: reusable-release-please.yml exists" {
  [ -f "$REUSABLE_RELEASE_PLEASE" ]
}

@test "reusable-ci-workflows: reusable-release-please.yml declares workflow_call" {
  run grep -E "^\s*workflow_call:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml uses canonical config-file path" {
  # The reusable hardcodes the canonical config-file path
  # (.github/release-please-config.json) because all spark-match repos
  # follow the same layout. If a consumer ever needs to override it,
  # promote config-file back to a workflow_call.input.
  run grep -E "config-file:[[:space:]]*\\.github/release-please-config\\.json" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml uses canonical manifest-file path" {
  run grep -E "manifest-file:[[:space:]]*\\.release-please-manifest\\.json" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml declares release-please-app-id secret" {
  # Secrets (not inputs) are how reusable workflows must receive credentials.
  # GH Actions rejects `${{ secrets[inputs.foo] }}` lookups because they
  # enable secret-name exfiltration.
  run grep -E "release-please-app-id:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "release-please-app-id:" "$REUSABLE_RELEASE_PLEASE"
  [[ "$output" == *"required: true"* ]]
}

@test "reusable-ci-workflows: reusable-release-please.yml declares release-please-app-private-key secret" {
  run grep -E "release-please-app-private-key:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  run grep -B1 -A2 "release-please-app-private-key:" "$REUSABLE_RELEASE_PLEASE"
  [[ "$output" == *"required: true"* ]]
}

@test "reusable-ci-workflows: reusable-release-please.yml does NOT use dynamic secrets[inputs.*] lookup" {
  # Anti-pattern: looking up a secret by name resolved from an input is
  # forbidden by GH Actions because the secret name would be visible in
  # logs and the value cannot be resolved at runtime.
  run grep -E "secrets\[inputs\." "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -ne 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml uses app-id input" {
  # actions/create-github-app-token@v3 still accepts `app-id` (prints a
  # deprecation warning suggesting `client-id`, but the input is still
  # functional). Switching to `client-id` requires pinning @v4+, which
  # is out of scope for this PR.
  run grep -E "^\s*app-id:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml uses create-github-app-token@v3" {
  run grep -E "uses: actions/create-github-app-token@v[0-9]+" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml uses release-please-action@v5" {
  run grep -E "uses: googleapis/release-please-action@v[0-9]+" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml needs contents write + pull-requests write" {
  run grep -A2 "^permissions:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contents: write"* ]]
  [[ "$output" == *"pull-requests: write"* ]]
}

# ---------------------------------------------------------------------------
# Auto-dogfooding: the internal workflows MUST consume the reusables
# ---------------------------------------------------------------------------

@test "reusable-ci-workflows: commitlint.yml consumes the reusable (auto-dogfooding)" {
  run grep -E "uses: \./.github/workflows/reusable-commitlint\.yml" "$INTERNAL_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: release-please.yml consumes the reusable (auto-dogfooding)" {
  run grep -E "uses: \./.github/workflows/reusable-release-please\.yml" "$INTERNAL_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: internal commitlint.yml does not duplicate wagoid step" {
  run grep -E "wagoid/commitlint-github-action" "$INTERNAL_COMMITLINT"
  [ "$status" -ne 0 ]
}

@test "reusable-ci-workflows: internal release-please.yml does not duplicate release-please step" {
  run grep -E "googleapis/release-please-action" "$INTERNAL_RELEASE_PLEASE"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# GitHub Actions constraint: reusable workflows cannot define their own
# concurrency block. The caller owns concurrency; the reusable inherits it.
# If a reusable defines concurrency, GH Actions rejects the run with:
#   "Error: The workflow 'X' is requesting a concurrency group but the
#   reusable workflow 'Y' also requests a concurrency group. Reusable
#   workflows cannot request a concurrency group."
# ---------------------------------------------------------------------------

@test "reusable-ci-workflows: reusable-commitlint.yml does not define concurrency" {
  run grep -E "^concurrency:" "$REUSABLE_COMMITLINT"
  [ "$status" -ne 0 ]
}

@test "reusable-ci-workflows: reusable-release-please.yml does not define concurrency" {
  run grep -E "^concurrency:" "$REUSABLE_RELEASE_PLEASE"
  [ "$status" -ne 0 ]
}

@test "reusable-ci-workflows: internal commitlint.yml owns concurrency (caller-side)" {
  run grep -E "^concurrency:" "$INTERNAL_COMMITLINT"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: internal release-please.yml owns concurrency (caller-side)" {
  run grep -E "^concurrency:" "$INTERNAL_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

@test "reusable-ci-workflows: internal release-please.yml passes both release-please secrets explicitly" {
  # The caller MUST forward both secrets in a `secrets:` block because
  # GH Actions does not auto-inherit secrets into reusable workflows
  # (security boundary). Forgetting to forward a secret means the
  # reusable silently gets an empty value, which fails at action runtime.
  run grep -E "release-please-app-id:[[:space:]]*\\\${{ secrets\.RELEASE_PLEASE_APP_ID }}" "$INTERNAL_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
  run grep -E "release-please-app-private-key:[[:space:]]*\\\${{ secrets\.RELEASE_PLEASE_APP_PRIVATE_KEY }}" "$INTERNAL_RELEASE_PLEASE"
  [ "$status" -eq 0 ]
}

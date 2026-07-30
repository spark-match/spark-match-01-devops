#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# secret-scanning.bats - regression guards for .gitleaks.toml +
# .githooks/pre-commit
# =============================================================================
# Locks down the secret-scanning posture added in PR-G7:
#   - .gitleaks.toml exists at repo root and is valid TOML.
#   - Config extends the default gitleaks rule set (useDefault = true)
#     so we get the upstream rules + our customizations.
#   - Custom AWS rules exist: aws-account-id, aws-role-arn,
#     aws-sts-session-token.
#   - Allowlists cover test fixtures (so the gitleaks CI job doesn't
#     fail on every PR because of literal "AKIA..." strings).
#   - Stopwords include "example", "test", "fake", "placeholder" so
#     documentation strings are not flagged.
#   - .githooks/pre-commit exists, is executable, and points at
#     `.gitleaks.toml` (not the upstream default).
#   - Pre-commit hook skips gracefully when gitleaks is not installed
#     (so contributors without it locally don't get blocked).
#   - SECURITY.md documents the admin task to enable native GH secret
#     scanning (the repo is on Free plan; native scanning is
#     unavailable until GHAS is purchased).
# =============================================================================

GITLEAKS_CONFIG="$BATS_TEST_DIRNAME/../../.gitleaks.toml"
PRE_COMMIT="$BATS_TEST_DIRNAME/../../.githooks/pre-commit"
SECURITY_MD="$BATS_TEST_DIRNAME/../../SECURITY.md"
CONTRIBUTING_MD="$BATS_TEST_DIRNAME/../../CONTRIBUTING.md"

# ---------------------------------------------------------------------------
# .gitleaks.toml existence + structure
# ---------------------------------------------------------------------------

@test "secret-scan: .gitleaks.toml exists at repo root" {
  [ -f "$GITLEAKS_CONFIG" ]
}

@test "secret-scan: .gitleaks.toml declares a title" {
  run grep -E '^title[[:space:]]*=' "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

@test "secret-scan: config extends the default gitleaks rule set" {
  # Without `useDefault = true`, we lose all upstream rules.
  run grep -A2 '^\[extend\]' "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"useDefault = true"* ]]
}

# ---------------------------------------------------------------------------
# Allowlists (so gitleaks doesn't flag fixtures)
# ---------------------------------------------------------------------------

@test "secret-scan: allowlists tests/fixtures/ so fake AKIA strings pass" {
  run grep -E "tests/fixtures/" "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

@test "secret-scan: allowlists docs/ (documentation strings)" {
  run grep -E "docs/" "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

@test "secret-scan: allowlists CHANGELOG.md (historical references)" {
  run grep -E "CHANGELOG" "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

@test "secret-scan: allowlists examples/*.md (illustrative ARNs)" {
  run grep -E "examples/" "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

@test "secret-scan: stopwords include 'example' to suppress fake-credential strings" {
  run grep -E "^[[:space:]]*'example'" "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

@test "secret-scan: stopwords include 'test', 'fake', 'placeholder'" {
  for word in test fake placeholder; do
    run grep -E "^[[:space:]]*'$word'" "$GITLEAKS_CONFIG"
    [ "$status" -eq 0 ]
  done
}

# ---------------------------------------------------------------------------
# Custom AWS rules
# ---------------------------------------------------------------------------

@test "secret-scan: custom aws-account-id rule exists" {
  run grep -E '^id[[:space:]]*=[[:space:]]*"aws-account-id"' "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

@test "secret-scan: custom aws-role-arn rule exists" {
  run grep -E '^id[[:space:]]*=[[:space:]]*"aws-role-arn"' "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

@test "secret-scan: custom aws-sts-session-token rule exists" {
  run grep -E '^id[[:space:]]*=[[:space:]]*"aws-sts-session-token"' "$GITLEAKS_CONFIG"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Pre-commit hook
# ---------------------------------------------------------------------------

@test "secret-scan: .githooks/pre-commit exists" {
  [ -f "$PRE_COMMIT" ]
}

@test "secret-scan: pre-commit hook is executable" {
  [ -x "$PRE_COMMIT" ]
}

@test "secret-scan: pre-commit hook points at .gitleaks.toml (custom config)" {
  # If the hook ran with the default config (no --config flag), the
  # allowlists + custom AWS rules wouldn't apply. The script stores
  # the config path in a variable $CONFIG which is resolved at runtime.
  # We verify both: (a) the --config flag is used, and (b) the
  # variable is initialized to .gitleaks.toml.
  run grep -E '\-\-config=' "$PRE_COMMIT"
  [ "$status" -eq 0 ]
  run grep -E 'CONFIG=.*\.gitleaks\.toml' "$PRE_COMMIT"
  [ "$status" -eq 0 ]
}

@test "secret-scan: pre-commit hook scans --staged only (not full history)" {
  run grep -E '\-\-staged' "$PRE_COMMIT"
  [ "$status" -eq 0 ]
}

@test "secret-scan: pre-commit hook skips gracefully when gitleaks not installed" {
  # The hook MUST NOT hard-fail when gitleaks is missing — CI still
  # catches secrets. Look for the skip branch.
  run grep -E 'command -v gitleaks' "$PRE_COMMIT"
  [ "$status" -eq 0 ]
  # The skip branch exits 0 (not 1) when gitleaks is missing.
  run grep -E 'not installed.*skipping' "$PRE_COMMIT"
  [ "$status" -eq 0 ]
}

@test "secret-scan: pre-commit hook uses 'protect --staged' (modern API)" {
  # `gitleaks protect` is the modern (v8+) subcommand. Older v7 used
  # `gitleaks --pre-commit`. Lock to the modern API.
  run grep -E 'gitleaks[[:space:]]+protect' "$PRE_COMMIT"
  [ "$status" -eq 0 ]
  ! grep -E 'gitleaks[[:space:]]+--pre-commit' "$PRE_COMMIT"
}

@test "secret-scan: pre-commit hook SPDX-licensed" {
  run grep -E 'SPDX-License-Identifier' "$PRE_COMMIT"
  [ "$status" -eq 0 ]
}

@test "secret-scan: pre-commit hook header documents the install command" {
  # Look for `git config core.hooksPath .githooks` in the header comment.
  run grep -E 'git config core.hooksPath' "$PRE_COMMIT"
  [ "$status" -eq 0 ]
  [[ "$output" == *".githooks"* ]]
}

# ---------------------------------------------------------------------------
# SECURITY.md documentation
# ---------------------------------------------------------------------------

@test "secret-scan: SECURITY.md mentions .gitleaks.toml" {
  run grep -E '\.gitleaks\.toml' "$SECURITY_MD"
  [ "$status" -eq 0 ]
}

@test "secret-scan: SECURITY.md mentions pre-commit hook" {
  run grep -E 'pre-commit' "$SECURITY_MD"
  [ "$status" -eq 0 ]
}

@test "secret-scan: SECURITY.md documents the admin task to enable native GH secret scanning" {
  run grep -iE 'secret scanning' "$SECURITY_MD"
  [ "$status" -eq 0 ]
  # The admin task section must mention Code security and analysis
  # (the actual UI path in repo settings).
  run grep -iE 'Code security and analysis|enable.*secret.scanning' "$SECURITY_MD"
  [ "$status" -eq 0 ]
}

@test "secret-scan: SECURITY.md lists custom AWS rules by name" {
  for rule in aws-account-id aws-role-arn aws-sts-session-token; do
    run grep -E "$rule" "$SECURITY_MD"
    [ "$status" -eq 0 ]
  done
}

@test "secret-scan: CONTRIBUTING.md documents `git config core.hooksPath .githooks`" {
  run grep -E 'core.hooksPath.*\.githooks' "$CONTRIBUTING_MD"
  [ "$status" -eq 0 ]
}
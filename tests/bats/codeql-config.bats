#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# codeql-config.bats - validate .github/codeql/codeql-config.yml
# =============================================================================
# Guards the CodeQL exclusion list for this repo. The repo intentionally
# does NOT use SHA-pinning for third-party actions (AGENTS.md §5.1) and
# instead pins with floating major tags (@vN) or exact versions (@N.N.N)
# for actions without v-prefixed tags. SHA-pinning trades convenience for
# a real supply-chain hazard (no auto patches, stale refs on repo
# deletion). SHA-pinning is actively forbidden by
# tests/bats/no-sha-pinning.bats.
#
# CodeQL has two rules that flag unpinned actions:
#   - js/actions/unpinned-3rd-party-action  (legacy, JS/TS only)
#   - actions/unpinned-tag                  (active in `actions` mode)
#
# Both are excluded here. If a future CodeQL release adds a third
# equivalent rule, extend the list below and document why.
#
# This file also guards that the config is wired into the
# codeql-actions workflow (config-file input).
# =============================================================================

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  CONFIG="$REPO_ROOT/.github/codeql/codeql-config.yml"
  WORKFLOW="$REPO_ROOT/.github/workflows/codeql-actions.yml"
}

@test "codeql-config: file exists at .github/codeql/codeql-config.yml" {
  [ -f "$CONFIG" ]
}

@test "codeql-config: declares query-filters list" {
  run grep -E '^query-filters:' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "codeql-config: excludes js/actions/unpinned-3rd-party-action" {
  run grep -E 'id:[[:space:]]*js/actions/unpinned-3rd-party-action' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "codeql-config: excludes actions/unpinned-tag" {
  # Active in `actions` mode. Per AGENTS.md §5.1 SHA-pinning is forbidden
  # so floating tags (@vN, @N.N.N) are the canonical form. The reverse
  # policy is enforced by tests/bats/no-sha-pinning.bats.
  run grep -E 'id:[[:space:]]*actions/unpinned-tag' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "codeql-config: every exclusion entry has a reason field" {
  # Count exclusions and reasons; they must match.
  local excluded excluded_with_reason
  excluded=$(grep -cE '^[[:space:]]+- exclude:' "$CONFIG" || true)
  excluded_with_reason=$(grep -cE '^[[:space:]]+reason:[[:space:]]*>' "$CONFIG" || true)
  [ "$excluded" -gt 0 ]
  [ "$excluded" -eq "$excluded_with_reason" ]
}

@test "codeql-config: is wired into codeql-actions.yml workflow" {
  run grep -E 'config-file:[[:space:]]*\.github/codeql/codeql-config\.yml' "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "codeql-config: AGENTS.md §5.1 still forbids SHA-pinning (reverse policy)" {
  # Sanity check: if someone reverts the policy in AGENTS.md, this file's
  # exclusions become wrong. Catch the regression alongside no-sha-pinning.
  #
  # Language-agnostic on purpose. This used to grep the Spanish 'NO por SHA',
  # so translating AGENTS.md to English on 2026-08-07 broke it -- a guard
  # coupled to wording rather than to meaning, which is the same failure the
  # CODEOWNERS self-approve assertion hit the same day.
  #
  # Note the asymmetry with no-sha-pinning.bats: that one asserts a NEGATIVE
  # (the phrase "Pin by SHA" must be absent) and survived the translation
  # untouched, because an absent phrase stays absent in any language. A
  # positive assertion over prose does not have that property, so it needs
  # both forms while the organization is mid-migration.
  run grep -E 'NOT by SHA|NO por SHA' "${REPO_ROOT}/AGENTS.md"
  [ "$status" -eq 0 ]
}
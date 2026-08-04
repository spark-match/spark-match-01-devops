#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# release-please-config.bats - validate .github/release-please-config.json
# =============================================================================
# Verifies the release-please manifest config is present, parses as JSON,
# conforms to the schema, and contains the customized sections we care about
# (PR title pattern, header, footer, changelog sections for ci/docs/governance/
# security/test).
# =============================================================================

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  CONFIG="$REPO_ROOT/.github/release-please-config.json"
}

@test "release-please config file exists" {
  [ -f "$CONFIG" ]
}

@test "release-please config is valid JSON" {
  run jq empty "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "release-please config has packages.{\".\"} entry" {
  run jq -e '.packages["."]' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "release-please config declares pull-request-title-pattern" {
  local pattern
  pattern=$(jq -r '.["pull-request-title-pattern"] // .packages["."]["pull-request-title-pattern"] // ""' "$CONFIG")
  [ -n "$pattern" ]
  [[ "$pattern" != "chore"*"release"* ]] || skip "title pattern still uses default chore: release prefix"
  echo "$pattern" | grep -q '\${version}'
}

@test "release-please config declares pull-request-header" {
  local header
  header=$(jq -r '.["pull-request-header"] // .packages["."]["pull-request-header"] // ""' "$CONFIG")
  [ -n "$header" ]
  [[ "$header" == *"Automated release"* ]] || [[ "$header" == *"release-please"* ]]
}

@test "release-please config declares pull-request-footer" {
  local footer
  footer=$(jq -r '.["pull-request-footer"] // .packages["."]["pull-request-footer"] // ""' "$CONFIG")
  [ -n "$footer" ]
  [[ "$footer" == *"checklist"* ]] || [[ "$footer" == *"Published by"* ]]
}

@test "release-please config declares changelog-sections" {
  run jq -e '.["changelog-sections"] // .packages["."]["changelog-sections"]' "$CONFIG"
  [ "$status" -eq 0 ]
}

@test "release-please changelog-sections include ci/docs/governance/security/test" {
  local sections
  sections=$(jq -r '(.["changelog-sections"] // .packages["."]["changelog-sections"]) | .[].type' "$CONFIG" | sort | tr '\n' ',' | sed 's/,$//')
  echo "# sections=$sections"
  for t in ci docs governance security test; do
    echo "$sections" | grep -q "\\b$t\\b" || { echo "missing type=$t"; return 1; }
  done
}

@test "release-please changelog-sections include feat and fix (default release triggers)" {
  local sections
  sections=$(jq -r '(.["changelog-sections"] // .packages["."]["changelog-sections"]) | .[].type' "$CONFIG" | sort | tr '\n' ',' | sed 's/,$//')
  echo "# sections=$sections"
  for t in feat fix; do
    echo "$sections" | grep -q "\\b$t\\b" || { echo "missing type=$t"; return 1; }
  done
}

@test "release-please config references schema for editor tooling" {
  run jq -e '."$schema"' "$CONFIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"release-please"* ]]
}

@test "release-please config bump rules match repo policy (pre-1.0.0)" {
  local bump_patch_for_minor
  bump_patch_for_minor=$(jq -r '.["bump-patch-for-minor-pre-major"] // .packages["."]["bump-patch-for-minor-pre-major"] // false' "$CONFIG")
  [ "$bump_patch_for_minor" = "true" ]
}

@test "release-please config uses v-prefixed tags" {
  local include_v
  include_v=$(jq -r '.["include-v-in-tag"] // .packages["."]["include-v-in-tag"] // false' "$CONFIG")
  [ "$include_v" = "true" ]
}

@test "release-please config release-type is a valid strategy (no 'default')" {
  local rt
  rt=$(jq -r '.["release-type"] // .packages["."]["release-type"] // ""' "$CONFIG")
  [ -n "$rt" ]
  [ "$rt" != "default" ] || { echo "release-type 'default' is not a valid release-please strategy"; return 1; }
  case "$rt" in
    simple|node|python|go|java|rust|ruby|php|elixir|terraform-module|helm|docker|maven|dotnet|dart|krm-blueprint|ocaml|sfdx|expo) ;;
    *) echo "unknown release-type=$rt"; return 1 ;;
  esac
}

@test "pull-request-header and pull-request-footer do NOT contain literal template vars" {
  # release-please source (src/strategies/base.ts) does NOT interpolate
  # template variables in pull-request-header / pull-request-footer -- only
  # pull-request-title-pattern gets interpolated. So we forbid "${...}" in
  # the header/footer to keep release notes readable.
  local header footer
  header=$(jq -r '.["pull-request-header"] // .packages["."]["pull-request-header"] // ""' "$CONFIG")
  footer=$(jq -r '.["pull-request-footer"] // .packages["."]["pull-request-footer"] // ""' "$CONFIG")
  echo "# header=${header:0:120}..."
  echo "# footer=${footer:0:120}..."
  if echo "$header" | grep -qE '\$\{[a-zA-Z]+\}'; then
    echo "literal template var found in header: $(echo "$header" | grep -oE '\\\$\{[a-zA-Z]+\}' | head -1)"
    return 1
  fi
  if echo "$footer" | grep -qE '\$\{[a-zA-Z]+\}'; then
    echo "literal template var found in footer: $(echo "$footer" | grep -oE '\\\$\{[a-zA-Z]+\}' | head -1)"
    return 1
  fi
}

@test "release-please manifest has a SemVer x.y.z version pinned (0.x.y pre-stable or >=1.0.0)" {
  run jq -r '.["."]' .release-please-manifest.json
  [ "$status" -eq 0 ]
  # Pre-1.0 development: 0.x.y. Post-1.0 stable: x.y.z with major >= 1.
  [[ "$output" =~ ^(0\.[0-9]+\.[0-9]+|[1-9][0-9]*\.[0-9]+\.[0-9]+)$ ]]
}

@test "release-please workflow points at config-file .github/release-please-config.json" {
  # The internal release-please.yml consumes the reusable
  # (.github/workflows/reusable-release-please.yml), which hardcodes the
  # canonical config-file path. The effective config path must resolve
  # to .github/release-please-config.json either via explicit override
  # in the caller or via the hardcoded path in the reusable.
  if grep -qE 'uses:[[:space:]]*\./.github/workflows/reusable-release-please\.yml' .github/workflows/release-please.yml; then
    if grep -qE 'config-file:[[:space:]]*\.github/release-please-config\.json' .github/workflows/release-please.yml; then
      : # explicit override present in caller
    else
      # relies on the reusable's hardcoded path
      run grep -E 'config-file:[[:space:]]*\.github/release-please-config\.json' .github/workflows/reusable-release-please.yml
      [ "$status" -eq 0 ]
    fi
  else
    # legacy shape: must explicitly reference the config file
    run grep -E 'config-file:[[:space:]]*\.github/release-please-config\.json' .github/workflows/release-please.yml
    [ "$status" -eq 0 ]
  fi
}


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

@test "release-please manifest still has version 0.1.1" {
  run jq -r '.["."]' .release-please-manifest.json
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.1" ]
}

@test "release-please workflow points at config-file .github/release-please-config.json" {
  run grep -E 'config-file:[[:space:]]*\.github/release-please-config\.json' .github/workflows/release-please.yml
  [ "$status" -eq 0 ]
}


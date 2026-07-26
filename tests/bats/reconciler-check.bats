#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# reconciler-check.bats - --check mode behavior
# =============================================================================
# Tests the dry-run style of the reconciler: computes drift, prints a table,
# and exits 0 if everything is in-sync, 1 if there is drift or any failure.
# =============================================================================

load 'helpers/reconciler'

setup() {
  load 'helpers/reconciler'
  write_default_manifest
  cd "$BATS_TEST_TMPDIR"
  mkdir -p fixtures

  # Default: team-devops resolves to id 12345 (used by spark-match-foo, bar).
  echo '{"id": 12345}' > fixtures/team-devops

  # Default: no rulesets exist on either repo.
  echo '[]' > fixtures/rulesets-list.json
}

teardown() {
  :
}

# -----------------------------------------------------------------------------
# In-sync / drift detection
# -----------------------------------------------------------------------------

@test "check: all in-sync when no rulesets exist (--check with empty list -> exit 0)" {
  # Empty rulesets list + 0 repos selected -> nothing to check -> exit 0.
  cat > fixtures/manifest.json <<'EOF'
{
  "version": 2,
  "defaults": {
    "approvals": 1,
    "allowedMergeMethods": ["squash"],
    "rulesetName": "test",
    "rulesetTarget": "branch",
    "rulesetEnforcement": "active"
  },
  "repositories": {}
}
EOF
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json"
  [ "$status" -eq 0 ]
}

@test "check: missing ruleset -> drift + exit 1" {
  # rulesets-list.json is "[]" so the script reports "drift reason=missing".
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 1 ]
  [[ "$output" == *"spark-match-foo"* ]]
  [[ "$output" == *"drift"* ]]
}

@test "check: existing ruleset with matching payload -> in-sync + exit 0" {
  # Build a payload that matches what the script will produce, save it as the
  # current ruleset detail. Stub team-devops + the ruleset list + the GET.
  fn_body=$(sed -n '/^build_desired_payload()/,/^}$/p' "$SCRIPT")
  eval "$fn_body"
  export MANIFEST="$BATS_TEST_TMPDIR/fixtures/manifest.json"
  payload=$(build_desired_payload "spark-match-foo" "12345")

  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  echo "$payload" > fixtures/rule-99.json

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"in-sync"* ]]
}

@test "check: existing ruleset with different payload -> drift + exit 1" {
  # A bare-minimum ruleset detail (no required_reviewers, no status checks)
  # does not match the manifest-driven payload -> drift.
  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  echo '{"id": 99, "name": "x", "target": "branch", "enforcement": "active",
        "conditions": {"ref_name": {"include": [], "exclude": []}},
        "bypass_actors": [], "rules": []}' \
    > fixtures/rule-99.json

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos spark-match-foo
  [ "$status" -eq 1 ]
  [[ "$output" == *"drift"* ]]
}

# -----------------------------------------------------------------------------
# --repos filter + manifest membership
# -----------------------------------------------------------------------------

@test "check: --repos r1,r2 narrows the processing scope" {
  # Process only spark-match-foo; bar is filtered out.
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo
  [ "$status" -eq 1 ]   # foo drifts (missing ruleset)
  [[ "$output" == *"spark-match-foo"* ]]
  [[ "$output" != *"spark-match-bar"* ]]
}

@test "check: --repos with a repo not in manifest -> state=failed, exit 1" {
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos not-in-manifest
  [ "$status" -eq 1 ]
  [[ "$output" == *"not-in-manifest"* ]]
}

@test "check: manifest entry missing reviewerTeam -> state=failed missing-reviewerTeam" {
  cat > fixtures/manifest.json <<'EOF'
{
  "version": 2,
  "defaults": {
    "approvals": 1,
    "allowedMergeMethods": ["squash"],
    "rulesetName": "test",
    "rulesetTarget": "branch",
    "rulesetEnforcement": "active"
  },
  "repositories": {
    "spark-match-foo": {
      "refs": ["~DEFAULT_BRANCH"],
      "filePatterns": ["**"],
      "statusChecks": []
    }
  }
}
EOF
  # The reason field is in the JSON output, not the table.
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo --json
  [ "$status" -eq 1 ]
  output_json=$(printf '%s\n' "$output" | grep -v '^\[INFO\]' | grep -v '^\[WARN\]' | grep -v '^\[ERR' | sed '1{/^$/d}')
  echo "$output_json" | jq -e '.[] | select(.repo == "spark-match-foo") | .reason == "missing-reviewerTeam"' >/dev/null
}

@test "check: team not found via API -> state=failed team-not-found" {
  # No fixtures/team-devops -> gh stub returns exit 1 for the team lookup.
  rm -f fixtures/team-devops
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo --json
  [ "$status" -eq 1 ]
  output_json=$(printf '%s\n' "$output" | grep -v '^\[INFO\]' | grep -v '^\[WARN\]' | grep -v '^\[ERR' | sed '1{/^$/d}')
  echo "$output_json" | jq -e '.[] | select(.repo == "spark-match-foo") | .reason == "team-not-found"' >/dev/null
}

# -----------------------------------------------------------------------------
# --json output
# -----------------------------------------------------------------------------

@test "check: --json emits valid JSON array" {
  # Empty manifest -> script outputs blank line + JSON array (jq -s wraps).
  # bats merges stderr (script's [INFO] line) into $output, so filter log
  # lines out and strip the leading blank line before parsing.
  cat > fixtures/manifest.json <<'EOF'
{
  "version": 2,
  "defaults": {
    "approvals": 1,
    "allowedMergeMethods": ["squash"],
    "rulesetName": "test",
    "rulesetTarget": "branch",
    "rulesetEnforcement": "active"
  },
  "repositories": {}
}
EOF
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --json
  [ "$status" -eq 0 ]
  output_json=$(printf '%s\n' "$output" | grep -v '^\[INFO\]' | grep -v '^\[WARN\]' | grep -v '^\[ERR' | sed '1{/^$/d}')
  echo "$output_json" | jq -e 'type == "array"' >/dev/null
}

@test "check: --json emits one entry per processed repo with state field" {
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo --json
  [ "$status" -eq 1 ]
  output_json=$(printf '%s\n' "$output" | grep -v '^\[INFO\]' | grep -v '^\[WARN\]' | grep -v '^\[ERR' | sed '1{/^$/d}')
  echo "$output_json" | jq -e '.[] | select(.repo == "spark-match-foo") | .state' >/dev/null
}

# -----------------------------------------------------------------------------
# Unexpected rulesets (foreign, with another name)
# -----------------------------------------------------------------------------

@test "check: unexpected ruleset (foreign name) -> state=unexpected, exit 1" {
  # rulesets-list contains a ruleset with target=branch and a name different
  # from the manifest's rulesetName. The script reports unexpected and aborts.
  echo '[{"id": 7, "name": "some-other-ruleset", "target": "branch"}]' \
    > fixtures/rulesets-list.json

  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo
  [ "$status" -eq 1 ]
  [[ "$output" == *"unexpected"* ]]
}

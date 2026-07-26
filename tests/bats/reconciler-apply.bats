#!/usr/bin/env bats
# =============================================================================
# reconciler-apply.bats - --apply mode behavior (PUT/POST + backup + dry-run)
# =============================================================================
# Tests the mutating path of the reconciler: PUT when a ruleset exists and
# drifts, POST when no ruleset exists, backup before any mutation, and the
# failure paths when the API rejects the write.
# =============================================================================

load 'helpers/reconciler'

setup() {
  load 'helpers/reconciler'
  write_default_manifest
  cd "$BATS_TEST_TMPDIR"
  mkdir -p fixtures

  # Default fixtures: team-devops resolves; no rulesets exist.
  echo '{"id": 12345}' > fixtures/team-devops
  echo '[]' > fixtures/rulesets-list.json
}

teardown() {
  :
}

# -----------------------------------------------------------------------------
# Dry-run: no PUT/POST
# -----------------------------------------------------------------------------

@test "apply --dry-run: in-sync repo -> no PUT/POST, exit 0" {
  # Empty manifest -> nothing to apply.
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
  run bash "$SCRIPT" --apply --dry-run --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json"
  [ "$status" -eq 0 ]
  ! grep -q "gh api -X PUT" "$BATS_TEST_TMPDIR/gh.log"
  ! grep -q "gh api -X POST" "$BATS_TEST_TMPDIR/gh.log"
}

@test "apply --dry-run: missing ruleset -> would-create, exit 0" {
  run bash "$SCRIPT" --apply --dry-run --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"would-create"* ]]
  ! grep -q "gh api -X POST" "$BATS_TEST_TMPDIR/gh.log"
}

@test "apply --dry-run: drifting ruleset -> would-update, exit 0" {
  # Set up an existing ruleset with a different (non-matching) payload.
  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  echo '{"id": 99, "name": "x", "target": "branch", "enforcement": "active",
        "conditions": {"ref_name": {"include": [], "exclude": []}},
        "bypass_actors": [], "rules": []}' \
    > fixtures/rule-99.json

  run bash "$SCRIPT" --apply --dry-run --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"would-update"* ]]
  ! grep -q "gh api -X PUT" "$BATS_TEST_TMPDIR/gh.log"
}

# -----------------------------------------------------------------------------
# Real apply: PUT/POST actually issued
# -----------------------------------------------------------------------------

@test "apply: missing ruleset -> POST issued, state=created, exit 0" {
  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo
  [ "$status" -eq 0 ]
  grep -q "gh api -X POST repos/spark-match/spark-match-foo/rulesets" "$BATS_TEST_TMPDIR/gh.log"
  [[ "$output" == *"created"* ]]
}

@test "apply: drifting ruleset -> PUT issued, backup created, state=updated" {
  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  echo '{"id": 99, "name": "x", "target": "branch", "enforcement": "active",
        "conditions": {"ref_name": {"include": [], "exclude": []}},
        "bypass_actors": [], "rules": []}' \
    > fixtures/rule-99.json

  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo
  [ "$status" -eq 0 ]
  grep -q "gh api -X PUT repos/spark-match/spark-match-foo/rulesets/99" "$BATS_TEST_TMPDIR/gh.log"
  [[ "$output" == *"updated"* ]]
  # A backup file must have been written to backups/rulesets/<ts>/
  find "$BATS_TEST_TMPDIR/backups" -name 'spark-match-foo-99.json' | grep -q .
}

@test "apply: in-sync repo -> no PUT/POST" {
  # Build a payload that matches what the script will produce.
  fn_body=$(sed -n '/^build_desired_payload()/,/^}$/p' "$SCRIPT")
  eval "$fn_body"
  export MANIFEST="$BATS_TEST_TMPDIR/fixtures/manifest.json"
  payload=$(build_desired_payload "spark-match-foo" "12345")

  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  echo "$payload" > fixtures/rule-99.json

  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo
  [ "$status" -eq 0 ]
  ! grep -q "gh api -X PUT" "$BATS_TEST_TMPDIR/gh.log"
  ! grep -q "gh api -X POST" "$BATS_TEST_TMPDIR/gh.log"
  [[ "$output" == *"in-sync"* ]]
}

# -----------------------------------------------------------------------------
# API rejection paths
# -----------------------------------------------------------------------------

@test "apply: PUT rejected by API -> state=failed PUT-rejected, exit 1" {
  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  echo '{"id": 99, "name": "x", "target": "branch", "enforcement": "active",
        "conditions": {"ref_name": {"include": [], "exclude": []}},
        "bypass_actors": [], "rules": []}' \
    > fixtures/rule-99.json
  # Force the PUT stub to fail.
  touch fixtures/put-rejected

  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo --json
  [ "$status" -eq 1 ]
  json_output_value=$(json_output)
  echo "$json_output_value" | jq -e '.[] | select(.repo == "spark-match-foo") | .reason == "PUT-rejected"' >/dev/null
}

@test "apply: POST rejected by API -> state=failed POST-rejected, exit 1" {
  touch fixtures/post-rejected
  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo --json
  [ "$status" -eq 1 ]
  json_output_value=$(json_output)
  echo "$json_output_value" | jq -e '.[] | select(.repo == "spark-match-foo") | .reason == "POST-rejected"' >/dev/null
}

# -----------------------------------------------------------------------------
# Unexpected rulesets (foreign)
# -----------------------------------------------------------------------------

@test "apply: unexpected foreign ruleset (no --prune-unexpected) -> abort" {
  echo '[{"id": 7, "name": "some-other-ruleset", "target": "branch"}]' \
    > fixtures/rulesets-list.json

  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo --json
  [ "$status" -eq 1 ]
  json_output_value=$(json_output)
  echo "$json_output_value" | jq -e '.[] | select(.repo == "spark-match-foo") | .state == "unexpected"' >/dev/null
  # No PUT/POST should have been issued for this repo.
  ! grep -q "spark-match-foo/rulesets/7" "$BATS_TEST_TMPDIR/gh.log"
}

# -----------------------------------------------------------------------------
# --backup-dir override
# -----------------------------------------------------------------------------

@test "apply: --backup-dir /custom/path overrides the default timestamp dir" {
  echo '[{"id": 99, "name": "spark-match-default-branch-protection"}]' \
    > fixtures/rulesets-list.json
  echo '{"id": 99, "name": "x", "target": "branch", "enforcement": "active",
        "conditions": {"ref_name": {"include": [], "exclude": []}},
        "bypass_actors": [], "rules": []}' \
    > fixtures/rule-99.json

  run bash "$SCRIPT" --apply --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo \
                       --backup-dir "$BATS_TEST_TMPDIR/custom-backup"
  [ "$status" -eq 0 ]
  find "$BATS_TEST_TMPDIR/custom-backup" -name 'spark-match-foo-99.json' | grep -q .
}

# -----------------------------------------------------------------------------
# --json
# -----------------------------------------------------------------------------

@test "apply: --json emits valid JSON array" {
  run bash "$SCRIPT" --apply --dry-run --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo --json
  [ "$status" -eq 0 ]
  output_json=$(json_output)
  echo "$output_json" | jq -e 'type == "array"' >/dev/null
  echo "$output_json" | jq -e '.[] | select(.repo == "spark-match-foo") | .state == "would-create"' >/dev/null
}

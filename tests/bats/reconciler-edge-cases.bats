#!/usr/bin/env bats
# =============================================================================
# reconciler-edge-cases.bats - Misc robustness tests
# =============================================================================
# Tests that don't fit cleanly in prereqs/check/apply: cache reuse, CRLF
# handling, --org override, whitespace in --repos, jq tolerance for unknown
# manifest fields, etc.
# =============================================================================

load 'helpers/reconciler'

setup() {
  load 'helpers/reconciler'
  write_default_manifest
  cd "$BATS_TEST_TMPDIR"
  mkdir -p fixtures
  echo '{"id": 12345}' > fixtures/team-devops
  echo '[]' > fixtures/rulesets-list.json
}

teardown() {
  :
}

# -----------------------------------------------------------------------------
# Team-id cache
# -----------------------------------------------------------------------------

@test "edge: team_id cache reuses resolved id for subsequent repos" {
  # The default manifest has spark-match-foo and spark-match-bar, both with
  # reviewerTeam=devops. The script should call `gh api orgs/.../teams/devops`
  # ONCE, then reuse the cached id for the second repo.
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo,spark-match-bar
  [ "$status" -eq 1 ]   # both have no rulesets -> drift
  # Count how many times the team endpoint was called.
  team_calls=$(grep -c "gh api orgs/spark-match/teams/devops" "$BATS_TEST_TMPDIR/gh.log" || true)
  [ "$team_calls" -eq 1 ]
}

# -----------------------------------------------------------------------------
# CRLF + whitespace in --repos
# -----------------------------------------------------------------------------

@test "edge: trailing whitespace + CRLF in --repos list is tolerated" {
  # Provide a CRLF-tainted repo list. The script strips \\r at line 305
  # via repo=\"${repo%\\$'\\r'}\" and skips empty entries.
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos $'spark-match-foo \r\nspark-match-bar\r\n'
  [ "$status" -eq 1 ]   # both drift
  # Both repos should appear in the output (proves CRLF was stripped).
  [[ "$output" == *"spark-match-foo"* ]]
  [[ "$output" == *"spark-match-bar"* ]]
}

# -----------------------------------------------------------------------------
# --org override
# -----------------------------------------------------------------------------

@test "edge: --org foo redirects all API calls to a different org" {
  # With --org=utpxpedition, every gh api call should target org=utpxpedition.
  # (Stub still returns the team id; we just verify the URL changed.)
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo --org utpxpedition
  [ "$status" -eq 1 ]
  grep -q "gh api orgs/utpxpedition/teams/devops" "$BATS_TEST_TMPDIR/gh.log"
  ! grep -q "gh api orgs/spark-match/teams/devops" "$BATS_TEST_TMPDIR/gh.log"
  grep -q "gh api repos/utpxpedition/spark-match-foo/rulesets" "$BATS_TEST_TMPDIR/gh.log"
}

# -----------------------------------------------------------------------------
# Unknown manifest fields (jq is permissive by default)
# -----------------------------------------------------------------------------

@test "edge: manifest with unknown top-level fields is tolerated (schema-strict=false)" {
  cat > fixtures/manifest.json <<'EOF'
{
  "version": 2,
  "schema": "spark-match.repository-governance/v2",
  "_note": "for testing",
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
      "reviewerTeam": "devops",
      "filePatterns": ["**"],
      "statusChecks": []
    }
  }
}
EOF
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" \
                       --repos spark-match-foo
  [ "$status" -eq 1 ]   # missing ruleset -> drift
  # No jq parse error -> script proceeded past manifest validation.
}

# -----------------------------------------------------------------------------
# --help output sanity
# -----------------------------------------------------------------------------

@test "edge: --help mentions --check, --apply, --repos, --manifest, --json" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  for flag in --check --apply --repos --manifest --json --org --backup-dir; do
    [[ "$output" == *"$flag"* ]]
  done
}

# -----------------------------------------------------------------------------
# Empty repos list (--repos "")
# -----------------------------------------------------------------------------

@test "edge: --repos '' (empty string) -> resolve_repos prints nothing" {
  # With --repos="" the filter is the empty string. resolve_repos checks
  # -n on REPOS_FILTER; '' is falsy, so jq is consulted. Manifest has 2
  # repos. To test the empty-list path, use an empty manifest instead.
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
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json" --repos ""
  [ "$status" -eq 0 ]   # nothing to do
}

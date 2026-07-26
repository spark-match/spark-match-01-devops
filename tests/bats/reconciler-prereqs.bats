#!/usr/bin/env bats
# =============================================================================
# reconciler-prereqs.bats - Argument parsing and prerequisite validation
# =============================================================================
# Tests the script's behavior BEFORE any `gh api` call lands: argument
# parsing, mode validation, manifest validation, and command/CLI checks.
# =============================================================================

load 'helpers/reconciler'

setup() {
  load 'helpers/reconciler'
  write_default_manifest
  cd "$BATS_TEST_TMPDIR"
}

teardown() {
  :
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

@test "prereqs: no args -> usage to stderr and exit 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[ERROR] Debe especificar --check o --apply"* ]]
}

@test "prereqs: --help -> usage to stdout and exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]] || [[ "$output" == *"configure-repo-rulesets"* ]]
}

@test "prereqs: unknown arg -> exit 2 with error message" {
  run bash "$SCRIPT" --check --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"[ERROR] Argumento desconocido: --bogus"* ]]
}

@test "prereqs: --check is accepted as MODE" {
  # Empty repositories in manifest -> resolve_repos prints nothing -> loop
  # body runs zero times -> script exits 0 with an empty table.
  cat > "$BATS_TEST_TMPDIR/fixtures/manifest.json" <<'EOF'
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

@test "prereqs: --apply is accepted as MODE" {
  cat > "$BATS_TEST_TMPDIR/fixtures/manifest.json" <<'EOF'
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
}

# -----------------------------------------------------------------------------
# Manifest validation
# -----------------------------------------------------------------------------

@test "prereqs: missing manifest file -> exit 2" {
  run bash "$SCRIPT" --check --manifest /nonexistent/manifest.json
  [ "$status" -eq 2 ]
  [[ "$output" == *"[ERROR] Manifiesto no encontrado"* ]]
}

@test "prereqs: manifest with wrong version -> exit 2" {
  echo '{"version": 1, "defaults": {}, "repositories": {}}' \
    > "$BATS_TEST_TMPDIR/fixtures/manifest.json"
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[ERROR] Manifiesto invalido o version no soportada"* ]]
}

@test "prereqs: manifest missing defaults.allowedMergeMethods -> exit 2" {
  cat > "$BATS_TEST_TMPDIR/fixtures/manifest.json" <<'EOF'
{
  "version": 2,
  "defaults": { "approvals": 1 },
  "repositories": {}
}
EOF
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json"
  [ "$status" -eq 2 ]
}

@test "prereqs: manifest missing repositories -> exit 2" {
  cat > "$BATS_TEST_TMPDIR/fixtures/manifest.json" <<'EOF'
{
  "version": 2,
  "defaults": {
    "approvals": 1,
    "allowedMergeMethods": ["squash"]
  }
}
EOF
  run bash "$SCRIPT" --check --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json"
  [ "$status" -eq 2 ]
}

# -----------------------------------------------------------------------------
# gh CLI prerequisite
# -----------------------------------------------------------------------------

@test "prereqs: gh auth status fail -> exit 2 even with valid args" {
  # Override the stub so auth status returns non-zero.
  gh() {
    echo "gh $*" >> "$BATS_TEST_TMPDIR/gh.log"
    if [[ "$1" == "auth" && "$2" == "status" ]]; then
      return 1
    fi
    return 0
  }
  export -f gh
  run bash "$SCRIPT" --check --repos "" --manifest "$BATS_TEST_TMPDIR/fixtures/manifest.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[ERROR] gh CLI no autenticado"* ]]
}

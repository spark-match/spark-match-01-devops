#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  ACTION_DIR="${REPO_ROOT}/.github/actions/codeql-fail-on-alerts"
  ACTION_SH="${ACTION_DIR}/action.sh"
  ACTION_YML="${ACTION_DIR}/action.yml"

  TEST_TEMP="$(mktemp -d)"
  export RUNNER_TEMP="${TEST_TEMP}"
}

teardown() {
  if [ -n "${TEST_TEMP:-}" ] && [ -d "${TEST_TEMP}" ]; then
    rm -rf "${TEST_TEMP}"
  fi
  unset RUNNER_TEMP
  unset SEVERITY_THRESHOLD
}

fake_sarif() {
  local content="$1"
  local dir="${TEST_TEMP}/codeql-actions"
  mkdir -p "${dir}"
  printf '%s' "${content}" > "${dir}/actions.sarif"
}

@test "action.yml exists at .github/actions/codeql-fail-on-alerts/" {
  [ -f "$ACTION_YML" ]
}

@test "action.sh exists at .github/actions/codeql-fail-on-alerts/" {
  [ -f "$ACTION_SH" ]
}

@test "action.sh is executable" {
  [ -x "$ACTION_SH" ]
}

@test "action.sh uses strict mode (set -euo pipefail)" {
  run head -1 "$ACTION_SH"
  [[ "$output" == *"#!/usr/bin/env bash"* ]]
  run grep -E '^set -euo pipefail' "$ACTION_SH"
  [ "$status" -eq 0 ]
}

@test "action.yml declares using: composite" {
  run grep -E '^[[:space:]]*using:[[:space:]]+composite' "$ACTION_YML"
  [ "$status" -eq 0 ]
}

@test "action.yml declares severity-threshold input with default warning" {
  run grep -E '^[[:space:]]+severity-threshold:' "$ACTION_YML"
  [ "$status" -eq 0 ]
  run grep -A3 'severity-threshold:' "$ACTION_YML"
  [[ "$output" == *"default: 'warning'"* ]]
}

@test "action.yml runs action.sh via \$GITHUB_ACTION_PATH (composite convention)" {
  run grep -E '\$GITHUB_ACTION_PATH/action\.sh' "$ACTION_YML"
  [ "$status" -eq 0 ]
}

@test "workflow codeql-actions.yml uses the composite action (not inline bash)" {
  run grep -E 'uses:[[:space:]]+\./\.github/actions/codeql-fail-on-alerts' \
    "${REPO_ROOT}/.github/workflows/codeql-actions.yml"
  [ "$status" -eq 0 ]
}

@test "workflow codeql-actions.yml does NOT contain 'set -euo pipefail' (no inline bash)" {
  run grep -E 'set -euo pipefail' "${REPO_ROOT}/.github/workflows/codeql-actions.yml"
  [ "$status" -ne 0 ]
}

@test "no SARIF directory: exits 0 with skip warning" {
  run bash "$ACTION_SH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"::warning::No SARIF directory found"* ]]
}

@test "SARIF directory exists but no SARIF file: exits 0 with skip warning" {
  mkdir -p "${TEST_TEMP}/codeql-actions"
  run bash "$ACTION_SH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"::warning::No SARIF file"* ]]
}

@test "SARIF with 0 alerts: exits 0, reports 0" {
  fake_sarif '{"runs":[{"results":[]}]}'
  run bash "$ACTION_SH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Alerts at severity >= warning: 0"* ]]
}

@test "SARIF with warning+error: exits 1, counts 2" {
  fake_sarif '{"runs":[{"results":[
    {"ruleId":"r1","level":"warning","locations":[{"physicalLocation":{"artifactLocation":{"uri":"a.yml"},"region":{"startLine":1}}}]},
    {"ruleId":"r2","level":"error","locations":[{"physicalLocation":{"artifactLocation":{"uri":"b.yml"},"region":{"startLine":2}}}]}
  ]}]}'
  run bash "$ACTION_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Alerts at severity >= warning: 2"* ]]
  [[ "$output" == *"::error::codeql found 2 alert"* ]]
}

@test "SARIF with note: note is excluded from warning count" {
  fake_sarif '{"runs":[{"results":[
    {"ruleId":"r1","level":"warning","locations":[{"physicalLocation":{"artifactLocation":{"uri":"a.yml"},"region":{"startLine":1}}}]},
    {"ruleId":"r2","level":"error","locations":[{"physicalLocation":{"artifactLocation":{"uri":"b.yml"},"region":{"startLine":2}}}]},
    {"ruleId":"r3","level":"note","locations":[{"physicalLocation":{"artifactLocation":{"uri":"c.yml"},"region":{"startLine":3}}}]}
  ]}]}'
  run bash "$ACTION_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Alerts at severity >= warning: 2"* ]]
  [[ "$output" != *"r3"* ]]
}

@test "SARIF without level field: defaults to warning (counted)" {
  fake_sarif '{"runs":[{"results":[
    {"ruleId":"no-level","locations":[{"physicalLocation":{"artifactLocation":{"uri":"x.yml"},"region":{"startLine":1}}}]}
  ]}]}'
  run bash "$ACTION_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Alerts at severity >= warning: 1"* ]]
}

@test "SEVERITY_THRESHOLD=error: warning alerts are not counted" {
  fake_sarif '{"runs":[{"results":[
    {"ruleId":"r1","level":"warning","locations":[{"physicalLocation":{"artifactLocation":{"uri":"a.yml"},"region":{"startLine":1}}}]},
    {"ruleId":"r2","level":"error","locations":[{"physicalLocation":{"artifactLocation":{"uri":"b.yml"},"region":{"startLine":2}}}]}
  ]}]}'
  SEVERITY_THRESHOLD=error run bash "$ACTION_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Alerts at severity >= error: 1"* ]]
}

@test "SEVERITY_THRESHOLD=note: all alerts are counted (including notes)" {
  fake_sarif '{"runs":[{"results":[
    {"ruleId":"r1","level":"warning","locations":[{"physicalLocation":{"artifactLocation":{"uri":"a.yml"},"region":{"startLine":1}}}]},
    {"ruleId":"r3","level":"note","locations":[{"physicalLocation":{"artifactLocation":{"uri":"c.yml"},"region":{"startLine":3}}}]}
  ]}]}'
  SEVERITY_THRESHOLD=note run bash "$ACTION_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Alerts at severity >= note: 2"* ]]
}

@test "SEVERITY_THRESHOLD=error: 0 alerts exits 0 (clean PR)" {
  fake_sarif '{"runs":[{"results":[
    {"ruleId":"r1","level":"warning","locations":[{"physicalLocation":{"artifactLocation":{"uri":"a.yml"},"region":{"startLine":1}}}]}
  ]}]}'
  SEVERITY_THRESHOLD=error run bash "$ACTION_SH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Alerts at severity >= error: 0"* ]]
}

@test "invalid severity threshold: exits 2 with error annotation" {
  fake_sarif '{"runs":[{"results":[]}]}'
  SEVERITY_THRESHOLD=invalid run bash "$ACTION_SH"
  [ "$status" -eq 2 ]
  [[ "$output" == *"::error::Invalid severity threshold 'invalid'"* ]]
}

@test "alerts display uses @tsv format (4 columns, no colon-join)" {
  fake_sarif '{"runs":[{"results":[
    {"ruleId":"r1","level":"warning","locations":[{"physicalLocation":{"artifactLocation":{"uri":"a.yml"},"region":{"startLine":1}}}]}
  ]}]}'
  run bash "$ACTION_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"::group::Alerts (severity, rule, file, line)"* ]]
  [[ "$output" == *"warning	r1	a.yml	1"* ]]
  [[ "$output" != *"a.yml:1"* ]]
}
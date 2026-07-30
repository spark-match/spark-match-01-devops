#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# container-deploy-ecr.bats - regression tests for container-deploy-ecr.yml
# =============================================================================
# Locks down SLSA defaults added in PR-G1:
#   - provenance input defaults to true (not false)
#   - sbom input defaults to true (not false)
#   - description strings reflect the SLSA rationale (not "dev speed")
#   - both inputs are still typed boolean (so callers can override)
#   - both inputs are still passed through to docker/build-push-action
#   - the deploy summary surfaces provenance + sbom state for audit trails
#
# A future PR that flips defaults back to false (e.g. "dev speed") MUST also
# update the description strings AND the README AND these tests.
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/container-deploy-ecr.yml"

# Extract the value of a workflow_call.inputs.<name>.default (boolean literal).
# Usage: input_default <name>
# Echoes the default (true|false|"<string>") and returns 0 on success, 1 if
# the input or its default cannot be found.
input_default() {
  local name="$1"
  awk -v want="$name" '
    BEGIN { in_wc=0; in_inputs=0; depth=0; found=0 }
    # Track workflow_call > inputs > <name> > default state.
    /^[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]*$/ {
      in_wc=0; in_inputs=0; depth=0; target=0
      if ($0 ~ /^on:[[:space:]]*$/) in_on=1; else in_on=0
      next
    }
    in_on && /^[[:space:]]+workflow_call:[[:space:]]*$/ { in_wc=1; next }
    in_wc && /^[[:space:]]+inputs:[[:space:]]*$/ { in_inputs=1; next }
    in_wc && /^[[:space:]]+secrets:[[:space:]]*$/ { in_inputs=0; next }
    in_inputs && /^[[:space:]]+outputs:[[:space:]]*$/ { in_inputs=0; next }
    in_inputs && $0 ~ "^[[:space:]]+" want ":[[:space:]]*$" { target=1; next }
    target && /^[[:space:]]+type:[[:space:]]+(string|boolean|choice|number|environment)/ {
      # sibling type declaration; still in target
      next
    }
    target && /^[[:space:]]+required:[[:space:]]+(true|false)/ { next }
    target && /^[[:space:]]+description:[[:space:]]+/ { next }
    target && /^[[:space:]]+default:[[:space:]]+(true|false)$/ {
      print $0 | "sed \"s/.*default:[[:space:]]*//\""
      found=1
      exit 0
    }
    target && /^[[:space:]]+default:[[:space:]]+/ {
      # Quoted string default: strip surrounding quotes if present.
      val = $0
      sub(/^[[:space:]]+default:[[:space:]]+/, "", val)
      gsub(/^["'\'']|["'\'']$/, "", val)
      print val
      found=1
      exit 0
    }
    END { if (!found) exit 1 }
  ' "$WORKFLOW"
}

# Extract the type of a workflow_call.inputs.<name> (string|boolean|...).
input_type() {
  local name="$1"
  awk -v want="$name" '
    BEGIN { in_wc=0; in_inputs=0; target=0 }
    /^[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]*$/ {
      in_wc=0; in_inputs=0; target=0
      if ($0 ~ /^on:[[:space:]]*$/) in_on=1; else in_on=0
      next
    }
    in_on && /^[[:space:]]+workflow_call:[[:space:]]*$/ { in_wc=1; next }
    in_wc && /^[[:space:]]+inputs:[[:space:]]*$/ { in_inputs=1; next }
    in_wc && /^[[:space:]]+(secrets|outputs):[[:space:]]*$/ { in_inputs=0; next }
    in_inputs && $0 ~ "^[[:space:]]+" want ":[[:space:]]*$" { target=1; next }
    target && /^[[:space:]]+type:[[:space:]]+(string|boolean|choice|number|environment)/ {
      match($0, /(string|boolean|choice|number|environment)/)
      print substr($0, RSTART, RLENGTH)
      exit 0
    }
  ' "$WORKFLOW"
}

# ---------------------------------------------------------------------------
# Default values
# ---------------------------------------------------------------------------

@test "container-deploy-ecr: provenance input defaults to true (SLSA)" {
  run input_default provenance
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "container-deploy-ecr: sbom input defaults to true (SLSA)" {
  run input_default sbom
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ---------------------------------------------------------------------------
# Types (still boolean so callers can override)
# ---------------------------------------------------------------------------

@test "container-deploy-ecr: provenance input is typed boolean" {
  run input_type provenance
  [ "$status" -eq 0 ]
  [ "$output" = "boolean" ]
}

@test "container-deploy-ecr: sbom input is typed boolean" {
  run input_type sbom
  [ "$status" -eq 0 ]
  [ "$output" = "boolean" ]
}

# ---------------------------------------------------------------------------
# Description strings reflect SLSA rationale, not "dev speed"
# ---------------------------------------------------------------------------

@test "container-deploy-ecr: provenance description mentions SLSA (not dev speed)" {
  run grep -E "^[[:space:]]+description:.*provenance.*default true" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SLSA"* ]]
  if grep -q "dev speed" "$WORKFLOW"; then
    echo "# 'dev speed' rationale should be removed when defaults are true"
    return 1
  fi
}

@test "container-deploy-ecr: sbom description mentions SPDX (not dev speed)" {
  run grep -E "^[[:space:]]+description:.*sbom.*default true" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SPDX"* ]]
}

# ---------------------------------------------------------------------------
# Inputs still plumb through to docker/build-push-action
# ---------------------------------------------------------------------------

@test "container-deploy-ecr: provenance input still passed to docker/build-push-action" {
  run grep -E "^[[:space:]]+provenance:[[:space:]]+\\\${{[[:space:]]*inputs.provenance[[:space:]]*}}" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "container-deploy-ecr: sbom input still passed to docker/build-push-action" {
  run grep -E "^[[:space:]]+sbom:[[:space:]]+\\\${{[[:space:]]*inputs.sbom[[:space:]]*}}" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Deploy summary surfaces provenance + sbom state
# ---------------------------------------------------------------------------

@test "container-deploy-ecr: deploy summary has a Provenance (SLSA) row" {
  run grep -E "^[[:space:]]+echo \"\\| Provenance \\(SLSA\\) \\|" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "container-deploy-ecr: deploy summary has a SBOM (SPDX) row" {
  run grep -E "^[[:space:]]+echo \"\\| SBOM \\(SPDX\\) \\|" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "container-deploy-ecr: deploy summary env exposes INPUTS_PROVENANCE" {
  run grep -E "^[[:space:]]+INPUTS_PROVENANCE:[[:space:]]+\\\${{[[:space:]]*inputs.provenance[[:space:]]*}}" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "container-deploy-ecr: deploy summary env exposes INPUTS_SBOM" {
  run grep -E "^[[:space:]]+INPUTS_SBOM:[[:space:]]+\\\${{[[:space:]]*inputs.sbom[[:space:]]*}}" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Cosign signing (PR-G3)
# ---------------------------------------------------------------------------

@test "container-deploy-ecr: declares cosign-sign input (boolean, default false)" {
  run grep -E "^[[:space:]]+cosign-sign:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+cosign-sign:" "$WORKFLOW"
  [[ "$output" == *"type: boolean"* ]]
  [[ "$output" == *"default: false"* ]]
}

@test "container-deploy-ecr: cosign-sign description mentions keyless + Sigstore" {
  # The description line directly follows the cosign-sign: key declaration.
  run grep -E -A1 "^[[:space:]]+cosign-sign:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"description: "* ]]
  [[ "$output" == *"Sigstore"* ]]
  [[ "$output" == *"keyless"* ]]
}

@test "container-deploy-ecr: cosign-installer SHA pinned to d7543c9 (v3.10.0)" {
  run grep -E "sigstore/cosign-installer@d7543c93d881b35a8faa02e8e3605f69b7a1ce62" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E "sigstore/cosign-installer@d7543c93d881b35a8faa02e8e3605f69b7a1ce62[[:space:]]*#[[:space:]]*v3\.10\.0" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "container-deploy-ecr: cosign-installer ref is NOT floating (@vN or @main)" {
  local offenders=()
  while IFS= read -r line; do
    if [[ "$line" == *sigstore/cosign-installer@* ]]; then
      after_at="${line##*sigstore/cosign-installer@}"
      sha_part="${after_at%% *}"
      if [[ ! "$sha_part" =~ ^[0-9a-f]{40}$ ]]; then
        offenders+=("$line")
      fi
    fi
  done < "$WORKFLOW"
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "# cosign-installer refs not SHA-pinned:"
    printf '  %s\n' "${offenders[@]}"
    return 1
  fi
}

@test "container-deploy-ecr: cosign install step is gated on cosign-sign=true" {
  # The Install cosign step has if: ${{ inputs.cosign-sign }}
  run grep -cE "^[[:space:]]+if:[[:space:]]+\\\$\{\{[[:space:]]*inputs.cosign-sign[[:space:]]*\}\}" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # Expect at least 2 occurrences (install + sign steps).
  [ "$output" -ge 2 ]
}

@test "container-deploy-ecr: cosign sign step iterates over each pushed tag" {
  run grep -E "cosign sign" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--yes"* ]]
  # Verify the step iterates over INPUTS_IMAGE_TAGS (comma-separated).
  run grep -B2 -A6 "cosign sign" "$WORKFLOW"
  [[ "$output" == *"INPUTS_IMAGE_TAGS"* ]]
  [[ "$output" == *"IFS=',' read -ra TAGS"* ]]
}

@test "container-deploy-ecr: cosign signing uses keyless (no COSIGN_KEY envvar)" {
  # Keyless mode is implicit (no --key flag, no COSIGN_KEY envvar). Verify
  # the signing step does NOT expose a key input.
  if grep -E "^[[:space:]]+COSIGN_KEY:" "$WORKFLOW"; then
    echo "# COSIGN_KEY should not be set in keyless mode"
    return 1
  fi
  if grep -E "cosign sign.*--key" "$WORKFLOW"; then
    echo "# cosign sign --key should not be used in keyless mode"
    return 1
  fi
}

@test "container-deploy-ecr: deploy summary has a Cosign sign row" {
  run grep -E "^[[:space:]]+echo \"\\| Cosign sign \\|" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "container-deploy-ecr: deploy summary env exposes INPUTS_COSIGN_SIGN" {
  run grep -E "^[[:space:]]+INPUTS_COSIGN_SIGN:[[:space:]]+\\\${{[[:space:]]*inputs.cosign-sign[[:space:]]*}}" "$WORKFLOW"
  [ "$status" -eq 0 ]
}
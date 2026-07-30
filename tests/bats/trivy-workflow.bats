#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# trivy-workflow.bats - regression tests for trivy.yml
# =============================================================================
# Locks down the Trivy reusable workflow contract added in PR-G2:
#   - workflow_call only (no push/pull_request triggers that would scan
#     this catalog repo on every PR; the catalog is a recipe provider,
#     not a scanning target)
#   - all inputs exposed (scan-type, scan-ref, image-ref, severity,
#     format, exit-code, ignore-unfixed, timeout, scanners)
#   - scan-type enum: fs | image | config
#   - severity default is CRITICAL (org policy: only block on CRITICAL
#     by default; callers can tighten to HIGH,CRITICAL)
#   - exit-code default is "1" so the workflow fails on findings
#   - ignore-unfixed default is true (avoid noise from upstream-pending)
#   - scan-ref default "." (whole repo)
#   - format default table (sarif opt-in)
#   - scanners default covers vuln + secret + misconfig
#   - Trivy action is SHA-pinned to ed142fd (v0.36.0)
#   - Separate steps for fs/config vs image (so image-ref is only passed
#     when scan-type=image)
#   - SARIF upload is conditional + uses always() so partial failures
#     still surface findings to Security tab
#   - Concurrency group keyed by (scan-type, ref) so parallel fs + image
#     scans on the same caller don't collide
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/trivy.yml"

# ---------------------------------------------------------------------------
# Trigger shape
# ---------------------------------------------------------------------------

@test "trivy: only workflow_call is exposed (no push/pull_request triggers)" {
  # Walk the YAML top-level: collect keys at indent 0 (the top-level
  # keys), then for each one collect its children. The on: block's
  # children must contain workflow_call: only.
  local triggers
  triggers=$(awk '
    BEGIN { in_on=0 }
    /^on:[[:space:]]*$/ { in_on=1; next }
    in_on && /^[[:space:]]{2}[a-zA-Z_-]+:[[:space:]]*$/ { print }
    in_on && /^[^[:space:]]/ { in_on=0 }
  ' "$WORKFLOW")
  echo "# triggers under on: block: $triggers"
  [[ "$triggers" == *"workflow_call:"* ]]
  [[ "$triggers" != *"push:"* ]]
  [[ "$triggers" != *"pull_request:"* ]]
  [[ "$triggers" != *"schedule:"* ]]
}

# ---------------------------------------------------------------------------
# Inputs exist with expected types and defaults
# ---------------------------------------------------------------------------

@test "trivy: declares scan-type input (enum: fs|image|config, default fs)" {
  run grep -E "^[[:space:]]+scan-type:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+scan-type:" "$WORKFLOW"
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"default: 'fs'"* ]]
}

@test "trivy: declares scan-ref input (default '.')" {
  run grep -E "^[[:space:]]+scan-ref:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+scan-ref:" "$WORKFLOW"
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"default: '.'"* ]]
}

@test "trivy: declares image-ref input (default empty)" {
  run grep -E "^[[:space:]]+image-ref:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+image-ref:" "$WORKFLOW"
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"default: ''"* ]]
}

@test "trivy: declares severity input (default CRITICAL)" {
  run grep -E "^[[:space:]]+severity:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+severity:" "$WORKFLOW"
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"default: 'CRITICAL'"* ]]
}

@test "trivy: declares format input (default table)" {
  run grep -E "^[[:space:]]+format:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+format:" "$WORKFLOW"
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"default: 'table'"* ]]
}

@test "trivy: declares exit-code input (default '1')" {
  run grep -E "^[[:space:]]+exit-code:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+exit-code:" "$WORKFLOW"
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"default: '1'"* ]]
}

@test "trivy: declares ignore-unfixed input (default true)" {
  run grep -E "^[[:space:]]+ignore-unfixed:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+ignore-unfixed:" "$WORKFLOW"
  [[ "$output" == *"type: boolean"* ]]
  [[ "$output" == *"default: true"* ]]
}

@test "trivy: declares timeout input (default 5m0s)" {
  run grep -E "^[[:space:]]+timeout:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+timeout:" "$WORKFLOW"
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"default: '5m0s'"* ]]
}

@test "trivy: declares scanners input (default vuln,secret,misconfig)" {
  run grep -E "^[[:space:]]+scanners:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E -B1 -A4 "^[[:space:]]+scanners:" "$WORKFLOW"
  [[ "$output" == *"type: string"* ]]
  [[ "$output" == *"default: 'vuln,secret,misconfig'"* ]]
}

# ---------------------------------------------------------------------------
# Trivy action SHA pin
# ---------------------------------------------------------------------------

@test "trivy: aquasecurity/trivy-action is SHA-pinned (no @vN or @main)" {
  # Any reference to trivy-action must be pinned by full SHA. We look for
  # the line and ensure it does NOT end with a floating ref.
  local offenders=()
  while IFS= read -r line; do
    if [[ "$line" == *aquasecurity/trivy-action@* ]]; then
      # Strip the SHA portion; the remainder after the @ must be empty
      # (pin) or a comment.
      after_at="${line##*aquasecurity/trivy-action@}"
      sha_part="${after_at%% *}"
      if [[ ! "$sha_part" =~ ^[0-9a-f]{40}$ ]]; then
        offenders+=("$line")
      fi
    fi
  done < "$WORKFLOW"
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "# trivy-action refs not SHA-pinned:"
    printf '  %s\n' "${offenders[@]}"
    return 1
  fi
}

@test "trivy: trivy-action SHA pin matches ed142fd (v0.36.0)" {
  run grep -E "aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -E "aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25[[:space:]]*#[[:space:]]*v0\.36\.0" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Scan-type branching
# ---------------------------------------------------------------------------

@test "trivy: image scan step is gated on scan-type == image" {
  # The image-mode step has an `if:` line with `inputs.scan-type == 'image'`.
  # Verify that line exists exactly once.
  run grep -cE "^[[:space:]]+if:[[:space:]]+\\\$\{\{[[:space:]]*inputs.scan-type[[:space:]]*==[[:space:]]*'image'[[:space:]]*\}\}" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "trivy: fs/config scan step is gated on scan-type != image" {
  run grep -E -B1 -A1 "scan-type != 'image'" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "trivy: image-ref is only consumed by the image-mode step" {
  # image-ref: ${{ inputs.image-ref }} should appear EXACTLY ONCE, on the
  # image-mode step (not on the fs step, which would be a wiring bug).
  local count
  count=$(grep -c "image-ref: \${{ inputs.image-ref }}" "$WORKFLOW")
  [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# SARIF upload
# ---------------------------------------------------------------------------

@test "trivy: SARIF upload is conditional on format == sarif with always()" {
  run grep -B1 -A4 "upload-sarif" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"if: \${{ inputs.format == 'sarif' && always() }}"* ]]
  [[ "$output" == *"github/codeql-action/upload-sarif"* ]]
}

@test "trivy: upload-sarif uses SHA pin (not @vN or @main)" {
  local offenders=()
  while IFS= read -r line; do
    if [[ "$line" == *github/codeql-action/upload-sarif@* ]]; then
      after_at="${line##*upload-sarif@}"
      sha_part="${after_at%% *}"
      if [[ ! "$sha_part" =~ ^[0-9a-f]{40}$ ]]; then
        offenders+=("$line")
      fi
    fi
  done < "$WORKFLOW"
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "# upload-sarif refs not SHA-pinned:"
    printf '  %s\n' "${offenders[@]}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Permissions / security posture
# ---------------------------------------------------------------------------

@test "trivy: permissions block is read-only (no write to contents or packages)" {
  run grep -A4 "^permissions:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contents: read"* ]]
  [[ "$output" != *"contents: write"* ]]
  [[ "$output" != *"packages: write"* ]]
}

@test "trivy: declares security-events: write (needed for SARIF upload)" {
  run grep -E "^[[:space:]]+security-events:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"security-events: write"* ]]
}

# ---------------------------------------------------------------------------
# Concurrency
# ---------------------------------------------------------------------------

@test "trivy: concurrency group keys on scan-type + ref" {
  run grep -E "^[[:space:]]+group:[[:space:]]+trivy-" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"inputs.image-ref"* ]]
  [[ "$output" == *"inputs.scan-ref"* ]]
}

@test "trivy: concurrency cancel-in-progress is false (preserve scan state)" {
  run grep -E -A2 "^concurrency:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cancel-in-progress: false"* ]]
}

# ---------------------------------------------------------------------------
# Summary step
# ---------------------------------------------------------------------------

@test "trivy: summary step is gated on always() so failures still surface" {
  run grep -B1 -A1 "Trivy summary" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"if: always()"* ]]
}

@test "trivy: summary branches on scan-type (image vs fs/config)" {
  run grep -E "scan-type == .image." "$WORKFLOW"
  [ "$status" -eq 0 ]
}
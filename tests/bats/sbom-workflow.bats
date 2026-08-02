#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# sbom-workflow.bats - regression tests for sbom.yml (CycloneDX SBOM release)
# =============================================================================
# Locks down the SBOM Release workflow contract:
#   - workflow_call triggers: release.published + workflow_dispatch (no
#     pull_request trigger so PRs from forks don't trigger SBOM uploads
#     to upstream releases)
#   - CycloneDX JSON format (not SPDX, not table)
#   - SBOM anchored to the release tag's exact commit (ref: tag)
#   - anchore/sbom-action pinned to v0.17.7 (floating minor; see
#     tests/bats/no-sha-pinning.bats for the global guard against
#     SHA-pinning)
#   - anchore/sbom-action configured with `upload-release-assets: true`
#     so the action itself uploads sbom.cdx.json to the GitHub Release
#     (the previous flow used a follow-up `gh release upload --clobber`
#     step, which was redundant; the action does it natively)
#   - The verify step downloads the action's workflow artifact back to
#     cwd (anchore/sbom-action uploads to /tmp + as artifact, NOT to
#     cwd by default) so the JSON shape can be validated
#   - The "Verify SBOM artifact" step parses the JSON and asserts
#     bomFormat == "CycloneDX" so a tooling regression gets caught
#   - permissions: contents: write (needed to upload release asset)
#   - Concurrency group keyed by tag; cancel-in-progress: false
#   - timeout-minutes: 10 (SBOM gen + verify typically <2 min)
#
# History:
#   - PR-G4 (#186): initial sbom-release.yml + sbom-release-workflow.bats
#   - rename (#188): sbom-release.yml → sbom.yml
#   - fix-sbom-verify-step: added download-artifact for verify step +
#     dropped the redundant `gh release upload` step. Updated this bats
#     file (which had been broken since PR #188 due to filename mismatch
#     and which checked for a removed step).
#   - drop-sha-pinning (#210): removed the SHA-pin enforcement tests
#     (anchore/sbom-action and actions/download-artifact) per the new
#     policy in AGENTS.md (no SHA-pinning; use @vN or @main). The
#     global guard against SHA-pinning is now in
#     tests/bats/no-sha-pinning.bats.
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/sbom.yml"

# ---------------------------------------------------------------------------
# Trigger shape
# ---------------------------------------------------------------------------

@test "sbom: triggers on release: published" {
  # Look for `types: [published]` block under `release:`.
  run grep -E "^[[:space:]]+types:[[:space:]]+\[published\]" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # Verify it's nested under release: (within 4 lines above).
  local above
  above=$(grep -B4 -E "^[[:space:]]+types:[[:space:]]+\[published\]" "$WORKFLOW")
  [[ "$above" == *"release:"* ]]
}

@test "sbom: also supports workflow_dispatch (manual re-run)" {
  run grep -E "^[[:space:]]+workflow_dispatch:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # The workflow_dispatch input should accept a `tag:` string.
  run grep -E "^[[:space:]]+tag:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "sbom: does NOT trigger on pull_request (would leak to upstream)" {
  # A PR-triggered SBOM workflow would attempt to upload against a real
  # release from a fork's PR — could be abused. Make sure we don't have it.
  if grep -qE '^[[:space:]]+pull_request:' "$WORKFLOW"; then
    echo "# sbom.yml must not have a pull_request trigger"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Anchore action pin (pinned to v0.17.7, see tests/bats/no-sha-pinning.bats
# for the global guard)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# SBOM format
# ---------------------------------------------------------------------------

@test "sbom: requests CycloneDX JSON format (not SPDX, not table)" {
  run grep -E "^[[:space:]]+format:[[:space:]]+cyclonedx-json" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # Explicitly forbid other formats.
  if grep -E "^[[:space:]]+format:[[:space:]]+(spdx-json|spdx-tag-value|github|packageurl|cyclonedx-xml)" "$WORKFLOW"; then
    echo "# sbom.yml must use cyclonedx-json, not the listed formats"
    return 1
  fi
}

@test "sbom: artifact name is sbom.cdx.json" {
  run grep -E "^[[:space:]]+artifact-name:[[:space:]]+sbom.cdx.json" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Anchored to release tag
# ---------------------------------------------------------------------------

@test "sbom: checkout uses the release tag (not branch HEAD)" {
  # Anchoring to the tag's commit means the SBOM matches the EXACT
  # contents that were released, not whatever happens to be on main.
  run grep -E "^[[:space:]]+ref:[[:space:]]+\\\${{[[:space:]]*github\\.event\\.release\\.tag_name" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Upload step (now via action's upload-release-assets)
# ---------------------------------------------------------------------------

@test "sbom: anchore/sbom-action uploads the SBOM directly to the Release" {
  # The action itself uploads sbom.cdx.json to the GitHub Release that
  # triggered the run; no follow-up `gh release upload` step is needed.
  run grep -E "^[[:space:]]+upload-release-assets:[[:space:]]+true" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "sbom: does NOT have a separate `gh release upload` step (redundant)" {
  # Regression guard for the previous design. The action's
  # `upload-release-assets: true` replaces the follow-up `gh release upload`
  # step entirely. If someone re-adds it, they'd duplicate the asset and
  # introduce drift on re-runs. Exclude comments so mentioning the old
  # design in the workflow header doesn't trip this guard.
  local offenders=()
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    # Skip comments (lines starting with #).
    if [[ "$line" =~ ^[[:space:]]*# ]]; then continue; fi
    if [[ "$line" == *"gh release upload"* ]]; then
      offenders+=("$line_num: $line")
    fi
  done < "$WORKFLOW"
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "# sbom.yml must not use 'gh release upload' outside comments; anchore/sbom-action handles it via upload-release-assets"
    printf '  %s\n' "${offenders[@]}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Verify step (download-artifact + bomFormat assertion)
# ---------------------------------------------------------------------------

@test "sbom: has a Download SBOM artifact step using actions/download-artifact" {
  run grep -B1 -A5 "Download SBOM artifact" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"actions/download-artifact@"* ]]
  # download-artifact pinned to @v4 (floating major); the global guard
  # against SHA-pinning is in tests/bats/no-sha-pinning.bats.
}

@test "sbom: Verify step parses JSON and asserts bomFormat=CycloneDX" {
  # Regression guard: catches tool-regression where the format silently
  # changes to SPDX or the file is empty.
  run grep -E "bomFormat" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CycloneDX"* ]]
}

@test "sbom: Verify step uses env-isolated SBOM_DIR (CodeQL guard)" {
  # The download path must be passed via env: and referenced as a shell
  # var, not interpolated directly in the run: block. PR #183 pattern.
  local offenders=()
  local in_verify=0
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "$line" =~ ^[[:space:]]*# ]]; then continue; fi
    # Detect "Verify SBOM artifact" step body.
    if [[ "$line" =~ -[[:space:]]name:[[:space:]]+Verify[[:space:]]+SBOM[[:space:]]+artifact ]]; then
      in_verify=1
      continue
    fi
    if [[ $in_verify -eq 1 ]]; then
      # Exit on next sibling step or block-key at indent <= verify step indent.
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        in_verify=0
      fi
      # Check for direct interpolation of `runner.temp` in the run block.
      if [[ "$line" =~ \$\{\{[[:space:]]*runner\.temp ]]; then
        # Exclude env: block lines (those are correct usage).
        if ! [[ "$line" =~ SBOM_DIR: ]]; then
          offenders+=("$line_num: $line")
        fi
      fi
    fi
  done < "$WORKFLOW"
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "# Verify SBOM step still has direct interpolation of runner.temp:"
    printf '  %s\n' "${offenders[@]}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Permissions + security posture
# ---------------------------------------------------------------------------

@test "sbom: permissions includes contents: write (needed for asset upload)" {
  run grep -E "^[[:space:]]+contents:[[:space:]]+write" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "sbom: declares only contents: write (no packages or deployments)" {
  run grep -A4 "^permissions:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contents: write"* ]]
  [[ "$output" != *"packages: write"* ]]
  [[ "$output" != *"deployments: write"* ]]
  [[ "$output" != *"id-token: write"* ]]
}

# ---------------------------------------------------------------------------
# Concurrency
# ---------------------------------------------------------------------------

@test "sbom: concurrency group keys on tag (one attach per tag)" {
  run grep -E "^[[:space:]]+group:[[:space:]]+sbom-release-" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"github.event.release.tag_name"* || "$output" == *"inputs.tag"* ]]
}

@test "sbom: concurrency cancel-in-progress is false (preserve upload state)" {
  run grep -A4 "^concurrency:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cancel-in-progress: false"* ]]
}

# ---------------------------------------------------------------------------
# Timeout + summary
# ---------------------------------------------------------------------------

@test "sbom: job declares timeout-minutes" {
  run grep -E "^[[:space:]]+timeout-minutes:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "sbom: summary step is gated on always() so failures still surface" {
  run grep -B1 -A1 "Attach summary" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"if: always()"* ]]
}
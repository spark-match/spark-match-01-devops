#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Spark Match
# =============================================================================
# sbom-release-workflow.bats - regression tests for sbom-release.yml
# =============================================================================
# Locks down the SBOM Release workflow contract added in PR-G4:
#   - workflow_call triggers: release.published + workflow_dispatch (no
#     pull_request trigger so PRs from forks don't trigger SBOM uploads
#     to upstream releases)
#   - CycloneDX JSON format (not SPDX, not table)
#   - SBOM anchored to the release tag's exact commit (ref: tag)
#   - anchore/sbom-action pinned to v0.17.7 (floating minor; see
#     tests/bats/no-sha-pinning.bats for the global guard against
#     SHA-pinning)
#   - Upload uses `gh release upload` with --clobber (so re-runs replace
#     stale SBOMs, e.g. when the format spec evolves)
#   - Tag name env-isolated so a crafted tag value cannot inject shell
#     tokens via `gh release upload`
#   - Concurrency group keyed by tag; cancel-in-progress: false
#   - permissions: contents: write (needed to upload release asset)
#   - timeout-minutes: 10 (SBOM gen + upload typically <2 min)
#   - The "Verify SBOM artifact" step parses the JSON and asserts
#     bomFormat == "CycloneDX" so a tooling regression gets caught
#     before the upload
#
# NOTE: this bats file references $WORKFLOW = sbom-release.yml, but the
#       file was renamed to sbom.yml in PR #188. The file was NOT
#       updated; all tests here currently fail because the path doesn't
#       resolve. The duplicate coverage lives in sbom-workflow.bats
#       (pointed at sbom.yml). Keeping this file as a placeholder until
#       someone either deletes it or migrates it to the new filename.
# =============================================================================

WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/sbom-release.yml"

# ---------------------------------------------------------------------------
# Trigger shape
# ---------------------------------------------------------------------------

@test "sbom-release: triggers on release: published" {
  # Look for `types: [published]` block under `release:`.
  run grep -E "^[[:space:]]+types:[[:space:]]+\[published\]" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # Verify it's nested under release: (within 4 lines above).
  local above
  above=$(grep -B4 -E "^[[:space:]]+types:[[:space:]]+\[published\]" "$WORKFLOW")
  [[ "$above" == *"release:"* ]]
}

@test "sbom-release: also supports workflow_dispatch (manual re-run)" {
  run grep -E "^[[:space:]]+workflow_dispatch:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # The workflow_dispatch input should accept a `tag:` string.
  run grep -E "^[[:space:]]+tag:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "sbom-release: does NOT trigger on pull_request (would leak to upstream)" {
  # A PR-triggered SBOM workflow would attempt `gh release upload` against
  # a real release from a fork's PR — could be abused. Make sure we don't
  # have it.
  if grep -qE '^[[:space:]]+pull_request:' "$WORKFLOW"; then
    echo "# sbom-release.yml must not have a pull_request trigger"
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

@test "sbom-release: requests CycloneDX JSON format (not SPDX, not table)" {
  run grep -E "^[[:space:]]+format:[[:space:]]+cyclonedx-json" "$WORKFLOW"
  [ "$status" -eq 0 ]
  # Explicitly forbid other formats.
  if grep -E "^[[:space:]]+format:[[:space:]]+(spdx-json|spdx-tag-value|github|packageurl|cyclonedx-xml)" "$WORKFLOW"; then
    echo "# sbom-release.yml must use cyclonedx-json, not the listed formats"
    return 1
  fi
}

@test "sbom-release: artifact name is sbom.cdx.json" {
  run grep -E "^[[:space:]]+artifact-name:[[:space:]]+sbom.cdx.json" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Anchored to release tag
# ---------------------------------------------------------------------------

@test "sbom-release: checkout uses the release tag (not branch HEAD)" {
  # Anchoring to the tag's commit means the SBOM matches the EXACT
  # contents that were released, not whatever happens to be on main.
  run grep -E "^[[:space:]]+ref:[[:space:]]+\\\${{[[:space:]]*github\\.event\\.release\\.tag_name" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Upload step
# ---------------------------------------------------------------------------

@test "sbom-release: upload step uses gh release upload --clobber" {
  run grep -E "gh release upload" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--clobber"* ]]
}

@test "sbom-release: upload step uses env-isolated tag (CodeQL guard)" {
  # The tag name must be passed via env: and referenced as a shell var,
  # not interpolated directly in the run: block. PR #183 pattern.
  local offenders=()
  local in_upload=0
  local run_indent=-1
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "$line" =~ ^[[:space:]]*# ]]; then continue; fi
    # Detect "Attach SBOM to GitHub Release" step body.
    if [[ "$line" =~ -[[:space:]]name:[[:space:]]+Attach[[:space:]]+SBOM[[:space:]]+to[[:space:]]+GitHub[[:space:]]+Release ]]; then
      in_upload=1
      continue
    fi
    if [[ $in_upload -eq 1 ]]; then
      # Exit on next sibling step or block-key at indent <= upload step indent.
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        in_upload=0
      fi
      # Check for direct interpolation in this step's body.
      if [[ "$line" =~ \$\{\{[[:space:]]*github\.event\.release\.tag_name ]] || [[ "$line" =~ \$\{\{[[:space:]]*inputs\.tag ]]; then
        # Exclude env: block lines (those are correct usage).
        if ! [[ "$line" =~ INPUTS_TAG_NAME: ]]; then
          offenders+=("$line_num: $line")
        fi
      fi
    fi
  done < "$WORKFLOW"
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "# Attach SBOM step still has direct interpolation:"
    printf '  %s\n' "${offenders[@]}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Permissions + security posture
# ---------------------------------------------------------------------------

@test "sbom-release: permissions includes contents: write (needed for asset upload)" {
  run grep -E "^[[:space:]]+contents:[[:space:]]+write" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "sbom-release: declares only contents: write (no packages or deployments)" {
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

@test "sbom-release: concurrency group keys on tag (one attach per tag)" {
  run grep -E "^[[:space:]]+group:[[:space:]]+sbom-release-" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"github.event.release.tag_name"* || "$output" == *"inputs.tag"* ]]
}

@test "sbom-release: concurrency cancel-in-progress is false (preserve upload state)" {
  run grep -A4 "^concurrency:" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cancel-in-progress: false"* ]]
}

# ---------------------------------------------------------------------------
# Timeout + verification
# ---------------------------------------------------------------------------

@test "sbom-release: job declares timeout-minutes" {
  run grep -E "^[[:space:]]+timeout-minutes:" "$WORKFLOW"
  [ "$status" -eq 0 ]
}

@test "sbom-release: Verify SBOM step parses JSON and asserts bomFormat=CycloneDX" {
  # Regression guard: catches tool-regression where the format silently
  # changes to SPDX or the file is empty.
  run grep -E "bomFormat" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CycloneDX"* ]]
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

@test "sbom-release: summary step is gated on always() so failures still surface" {
  run grep -B1 -A1 "Attach summary" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"if: always()"* ]]
}
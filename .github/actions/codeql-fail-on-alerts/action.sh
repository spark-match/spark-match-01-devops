#!/usr/bin/env bash
set -euo pipefail

SEVERITY="${SEVERITY_THRESHOLD:-warning}"

SARIF_DIR=$(find "${RUNNER_TEMP}" -maxdepth 1 -type d -name 'codeql-*' 2>/dev/null | head -n1 || true)
if [ -z "${SARIF_DIR}" ]; then
  echo "::warning::No SARIF directory found; skipping alert check."
  exit 0
fi
SARIF_FILE=$(find "${SARIF_DIR}" -maxdepth 1 -type f -name '*.sarif' 2>/dev/null | head -n1 || true)
if [ -z "${SARIF_FILE}" ]; then
  echo "::warning::No SARIF file in ${SARIF_DIR}; skipping alert check."
  exit 0
fi
echo "Analyzing SARIF: ${SARIF_FILE}"

case "${SEVERITY}" in
  error)
    SELECTOR='.level == "error"'
    ;;
  warning)
    SELECTOR='(.level // "warning") == "warning" or .level == "error"'
    ;;
  note)
    SELECTOR='true'
    ;;
  *)
    echo "::error::Invalid severity threshold '${SEVERITY}' (expected: error|warning|note)"
    exit 2
    ;;
esac

COUNT=$(jq "[.runs[].results[] | select(${SELECTOR})] | length" "${SARIF_FILE}")
echo "Alerts at severity >= ${SEVERITY}: ${COUNT}"
if [ "${COUNT}" -gt 0 ]; then
  echo "::error::CodeQL found ${COUNT} alert(s) at severity >= ${SEVERITY} in this PR."
  echo "::group::Alerts (severity, rule, file, line)"
  jq -r ".runs[].results[] | select(${SELECTOR}) | [.level // \"warning\", .ruleId // \"unknown\", .locations[0].physicalLocation.artifactLocation.uri // \"?\", .locations[0].physicalLocation.region.startLine // \"?\"] | @tsv" "${SARIF_FILE}" 2>/dev/null \
    | sort -u \
    | head -n 20 || true
  echo "::endgroup::"
  exit 1
fi
#!/usr/bin/env bash
set -euo pipefail

version="${INPUT_VERSION:-}"
install_dir="${INPUT_INSTALL_DIR:-}"

if [[ -z "$version" ]]; then
  echo "::error::version input is required" >&2
  exit 1
fi
if [[ -z "$install_dir" ]]; then
  echo "::error::install-dir input is required (or its default must resolve)" >&2
  exit 1
fi

mkdir -p "$install_dir"

curl --fail --silent --show-error --location --retry 3 --retry-delay 5 \
  "https://raw.githubusercontent.com/rhysd/actionlint/v${version}/scripts/download-actionlint.bash" \
  | bash -s -- "$version" "$install_dir"

executable="${install_dir}/actionlint"
if [[ ! -x "$executable" ]]; then
  echo "::error::actionlint binary not found at ${executable} after install" >&2
  exit 1
fi

{
  echo "executable=${executable}"
} >> "${GITHUB_OUTPUT:-/dev/null}"

echo "Installed: $("$executable" --version)"

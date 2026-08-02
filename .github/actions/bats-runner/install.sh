#!/usr/bin/env bash
set -euo pipefail

BATS_VERSION="${BATS_VERSION:-1.11.1}"
TMP_DIR="$(mktemp -d)"
curl --fail --silent --show-error --location --retry 3 --retry-delay 5 \
  "https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz" \
  -o "${TMP_DIR}/bats.tar.gz"
tar -xzf "${TMP_DIR}/bats.tar.gz" -C "${TMP_DIR}"
sudo "${TMP_DIR}/bats-core-${BATS_VERSION}/install.sh" /usr/local
bats --version
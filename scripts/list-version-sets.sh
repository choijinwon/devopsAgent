#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for file in "${ROOT_DIR}/versions/"*.env; do
  set -a
  # shellcheck disable=SC1090
  source "${file}"
  set +a
  printf "%s\t%s\n" "${VERSION_SET}" "${file#${ROOT_DIR}/}"
done

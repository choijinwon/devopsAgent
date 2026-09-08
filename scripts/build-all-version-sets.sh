#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAYER="${LAYER:-all}"

while IFS=$'\t' read -r version_set _path; do
  LAYER="${LAYER}" "${ROOT_DIR}/scripts/build-version-set.sh" "${version_set}"
done < <("${ROOT_DIR}/scripts/list-version-sets.sh")

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_SET_NAME="${1:-${VERSION_SET:-u24-cu128-py312-torch210-mlflow3152-kserve0190}}"
LAYER="${LAYER:-g6}"

version_file=""
for candidate in "${ROOT_DIR}/versions/"*.env; do
  if grep -q "^VERSION_SET=${VERSION_SET_NAME}$" "${candidate}"; then
    version_file="${candidate}"
    break
  fi
done

if [[ -z "${version_file}" ]]; then
  echo "Unknown VERSION_SET: ${VERSION_SET_NAME}" >&2
  echo "Available version sets:" >&2
  "${ROOT_DIR}/scripts/list-version-sets.sh" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${version_file}"
set +a

export IMAGE_TAG="${IMAGE_TAG:-${VERSION_SET}}"
export UBUNTU_VERSION CUDA_IMAGE PYTHON_PACKAGE PYTORCH_INDEX_URL
export PYTORCH_VERSION TORCHVISION_VERSION TORCHAUDIO_VERSION
export MLFLOW_VERSION KSERVE_PYTHON_VERSION APP_UID APP_GID APP_USER

"${ROOT_DIR}/scripts/build-docker-layer.sh" "${LAYER}"

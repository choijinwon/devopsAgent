#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAYER="${1:-g6}"
IMAGE_REPO="${IMAGE_REPO:-localhost:8080/library/layered-kserve}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
PUSH="${PUSH:-false}"
PLATFORM="${PLATFORM:-linux/amd64}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
BUILDCTL_ADDR="${BUILDCTL_ADDR:-}"

BUILD_ARGS=(
  "UBUNTU_VERSION=${UBUNTU_VERSION:-24.04}"
  "CUDA_IMAGE=${CUDA_IMAGE:-nvidia/cuda:12.8.2-runtime-ubuntu24.04}"
  "PYTHON_PACKAGE=${PYTHON_PACKAGE:-python3.12}"
  "PYTORCH_INDEX_URL=${PYTORCH_INDEX_URL:-https://download.pytorch.org/whl/cu128}"
  "PYTORCH_VERSION=${PYTORCH_VERSION:-2.10.0}"
  "TORCHVISION_VERSION=${TORCHVISION_VERSION:-0.25.0}"
  "TORCHAUDIO_VERSION=${TORCHAUDIO_VERSION:-2.10.0}"
  "MLFLOW_VERSION=${MLFLOW_VERSION:-3.15.2}"
  "KSERVE_PYTHON_VERSION=${KSERVE_PYTHON_VERSION:-0.19.0}"
  "APP_UID=${APP_UID:-10001}"
  "APP_GID=${APP_GID:-10001}"
  "APP_USER=${APP_USER:-model}"
)

target_for_layer() {
  case "$1" in
    g0) echo "g0-ubuntu" ;;
    g1) echo "g1-cuda" ;;
    g2) echo "g2-python" ;;
    g3) echo "g3-pytorch" ;;
    g4) echo "g4-mlflow" ;;
    g5) echo "g5-kserve" ;;
    g6) echo "g6-id" ;;
    *) echo "unknown layer: $1" >&2 && exit 1 ;;
  esac
}

build_one() {
  local layer="$1"
  local target
  target="$(target_for_layer "${layer}")"
  local image="${IMAGE_REPO}:${IMAGE_TAG}-${layer}"

  if [[ -n "${BUILDCTL_ADDR}" ]]; then
    local buildctl_args=()
    for build_arg in "${BUILD_ARGS[@]}"; do
      buildctl_args+=(--opt "build-arg:${build_arg}")
    done

    buildctl --addr "${BUILDCTL_ADDR}" build \
      --frontend dockerfile.v0 \
      --local context="${ROOT_DIR}" \
      --local dockerfile="${ROOT_DIR}" \
      --opt filename="${DOCKERFILE}" \
      --opt target="${target}" \
      --opt platform="${PLATFORM}" \
      "${buildctl_args[@]}" \
      --output "type=image,name=${image},push=${PUSH}"
  else
    local push_flag=()
    if [[ "${PUSH}" == "true" ]]; then
      push_flag=(--push)
    else
      push_flag=(--load)
    fi

    local docker_args=()
    for build_arg in "${BUILD_ARGS[@]}"; do
      docker_args+=(--build-arg "${build_arg}")
    done

    docker buildx build \
      --platform "${PLATFORM}" \
      --file "${ROOT_DIR}/${DOCKERFILE}" \
      --target "${target}" \
      --tag "${image}" \
      "${docker_args[@]}" \
      "${push_flag[@]}" \
      "${ROOT_DIR}"
  fi
}

if [[ "${LAYER}" == "all" ]]; then
  for layer in g0 g1 g2 g3 g4 g5 g6; do
    build_one "${layer}"
  done
else
  build_one "${LAYER}"
fi

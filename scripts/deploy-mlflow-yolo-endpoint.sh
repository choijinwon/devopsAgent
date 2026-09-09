#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARBOR_SERVER="${HARBOR_SERVER:-localhost:8080}"
HARBOR_USERNAME="${HARBOR_USERNAME:-admin}"
HARBOR_PASSWORD_FILE="${HARBOR_PASSWORD_FILE:-${ROOT_DIR}/local/harbor/admin-password}"
BASE_IMAGE="${BASE_IMAGE:-${HARBOR_SERVER}/library/layered-kserve:u24-cu128-py312-torch210-mlflow3152-kserve0190-c269b4c78ded-g6}"
IMAGE="${IMAGE:-${HARBOR_SERVER}/library/yolo-mlflow-kserve:v1}"
if [[ -z "${PLATFORM:-}" ]]; then
  node_arch="$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}')"
  PLATFORM="linux/${node_arch}"
fi

if [[ -z "${HARBOR_PASSWORD:-}" && -f "${HARBOR_PASSWORD_FILE}" ]]; then
  HARBOR_PASSWORD="$(<"${HARBOR_PASSWORD_FILE}")"
fi
: "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD or provide local/harbor/admin-password}"

printf '%s' "${HARBOR_PASSWORD}" | docker login "${HARBOR_SERVER}" \
  --username "${HARBOR_USERNAME}" --password-stdin

docker buildx build \
  --platform "${PLATFORM}" \
  --file "${ROOT_DIR}/examples/mlflow-yolo/Dockerfile" \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --tag "${IMAGE}" \
  --push \
  "${ROOT_DIR}"

kubectl apply -f "${ROOT_DIR}/k8s/mlflow-yolo/inferenceservice.yaml"
kubectl -n model-serving wait \
  --for=condition=Ready \
  inferenceservice/yolo11n-detector \
  --timeout=10m
kubectl -n model-serving get inferenceservice yolo11n-detector

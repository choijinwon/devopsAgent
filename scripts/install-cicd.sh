#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARBOR_SERVER="${HARBOR_SERVER:-host.docker.internal:8080}"
HARBOR_USERNAME="${HARBOR_USERNAME:-admin}"
HARBOR_PASSWORD_FILE="${HARBOR_PASSWORD_FILE:-${ROOT_DIR}/local/harbor/admin-password}"
if [[ -z "${HARBOR_PASSWORD:-}" && -f "${HARBOR_PASSWORD_FILE}" ]]; then
  HARBOR_PASSWORD="$(<"${HARBOR_PASSWORD_FILE}")"
fi
HARBOR_PASSWORD="${HARBOR_PASSWORD:-Harbor12345}"
GIT_USERNAME="${GIT_USERNAME:-}"
GIT_TOKEN="${GIT_TOKEN:-}"
INSTALL_BUILDKIT="${INSTALL_BUILDKIT:-false}"

if [[ "${INSTALL_BUILDKIT}" == "true" ]]; then
  kubectl apply -k "${ROOT_DIR}/clusters/dev/layers/g3-buildkit"
  kubectl -n buildkit rollout status deployment/buildkitd --timeout=300s
fi

kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace model-serving --dry-run=client -o yaml | kubectl apply -f -

kubectl -n argo create configmap cicd-local-source \
  --from-file=Dockerfile="${ROOT_DIR}/Dockerfile" \
  --from-file=version.env="${ROOT_DIR}/versions/u24-cu128-py312-torch210.env" \
  --from-file=model_server.py="${ROOT_DIR}/src/model_server.py" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n argo create secret docker-registry harbor-docker-config \
  --docker-server="${HARBOR_SERVER}" \
  --docker-username="${HARBOR_USERNAME}" \
  --docker-password="${HARBOR_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n model-serving create secret docker-registry harbor-pull \
  --docker-server="${HARBOR_SERVER}" \
  --docker-username="${HARBOR_USERNAME}" \
  --docker-password="${HARBOR_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

if [[ -n "${GIT_TOKEN}" ]]; then
  kubectl -n argo create secret generic cicd-git \
    --from-literal=username="${GIT_USERNAME}" \
    --from-literal=token="${GIT_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  kubectl -n argo get secret cicd-git >/dev/null 2>&1 || {
    echo "GIT_TOKEN is not set. CI can clone public repositories, but CD cannot push Helm values yet."
  }
fi

kubectl apply -k "${ROOT_DIR}/k8s/cicd"
kubectl -n argo get workflowtemplate layered-model-cicd

if ! kubectl -n buildkit get deployment buildkitd >/dev/null 2>&1; then
  echo "BuildKit is not installed. Install it separately before running the CI workflow."
fi

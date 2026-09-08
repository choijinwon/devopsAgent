#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${ROOT_DIR}/charts/layered-model"
REPO_DIR="$(mktemp -d)"
REPO_URL="http://local-helm-repo.argocd.svc.cluster.local"

cleanup() {
  rm -rf "${REPO_DIR}"
}
trap cleanup EXIT

helm package "${CHART_DIR}" --destination "${REPO_DIR}" >/dev/null
helm repo index "${REPO_DIR}" --url "${REPO_URL}"

kubectl -n argocd create configmap local-helm-repo-content \
  --from-file="${REPO_DIR}/index.yaml" \
  --from-file="${REPO_DIR}/layered-model-0.1.0.tgz" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -k "${ROOT_DIR}/clusters/dev/local-helm-repo"
kubectl -n argocd rollout restart deployment/local-helm-repo
kubectl -n argocd rollout status deployment/local-helm-repo --timeout=180s
kubectl apply -f "${ROOT_DIR}/clusters/dev/local-helm-repo/application.yaml"
kubectl -n argocd get application layered-model

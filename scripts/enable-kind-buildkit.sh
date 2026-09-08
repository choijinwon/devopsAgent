#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
context="$(kubectl config current-context)"

if [[ "${context}" != kind-* ]]; then
  echo "This helper is only for a local kind cluster. Current context: ${context}" >&2
  exit 1
fi

echo "Enabling the approved rootless BuildKit exceptions only in ${context}."
kubectl apply -k "${ROOT_DIR}/clusters/dev/overlays/kind/g3-buildkit"
kubectl -n buildkit scale deployment buildkitd --replicas=1
kubectl -n buildkit rollout status deployment/buildkitd --timeout=300s
"${ROOT_DIR}/scripts/configure-kind-harbor.sh"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${1:-dev}"

for layer_dir in "${ROOT_DIR}/clusters/${CLUSTER}/layers/"*; do
  if [[ -f "${layer_dir}/kustomization.yaml" ]]; then
    echo "validating ${layer_dir#${ROOT_DIR}/}"
    kubectl kustomize "${layer_dir}" >/dev/null
  fi
done

for overlay_dir in "${ROOT_DIR}/clusters/${CLUSTER}/overlays/"*/*; do
  if [[ -f "${overlay_dir}/kustomization.yaml" ]]; then
    echo "validating ${overlay_dir#${ROOT_DIR}/}"
    kubectl kustomize "${overlay_dir}" >/dev/null
  fi
done

echo "validating k8s/cicd"
kubectl kustomize "${ROOT_DIR}/k8s/cicd" >/dev/null

echo "validating charts/layered-model"
helm lint "${ROOT_DIR}/charts/layered-model" \
  -f "${ROOT_DIR}/charts/layered-model/values-local.yaml" >/dev/null

echo "validation complete"

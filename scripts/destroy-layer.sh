#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-dev}"
KSERVE_VERSION="${KSERVE_VERSION:-v0.20.0}"
ARGO_WORKFLOWS_VERSION="${ARGO_WORKFLOWS_VERSION:-v4.1.2}"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
LAYER="${1:-all}"

delete_kustomize() {
  local path="$1"
  kubectl delete -k "${ROOT_DIR}/${path}" --ignore-not-found=true
}

destroy_gitops() {
  delete_kustomize "clusters/${CLUSTER}/gitops-root"
}

destroy_g6() {
  kubectl delete --ignore-not-found=true -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve-cluster-resources.yaml"
  delete_kustomize "clusters/${CLUSTER}/layers/g6-kserve-runtimes"
}

destroy_g5() {
  kubectl delete --ignore-not-found=true -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve.yaml"
  delete_kustomize "clusters/${CLUSTER}/layers/g5-kserve-controller"
}

destroy_g4() {
  kubectl delete --ignore-not-found=true -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve-crds.yaml"
  delete_kustomize "clusters/${CLUSTER}/layers/g4-kserve-crds"
}

destroy_g3() {
  delete_kustomize "clusters/${CLUSTER}/layers/g3-buildkit"
}

destroy_g2() {
  kubectl delete -n argo --ignore-not-found=true -f "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/install.yaml"
  delete_kustomize "clusters/${CLUSTER}/layers/g2-argo-workflows"
}

destroy_g1() {
  kubectl delete -n argocd --ignore-not-found=true -f "${ARGOCD_MANIFEST_URL}"
  delete_kustomize "clusters/${CLUSTER}/layers/g1-argocd"
}

destroy_g0() {
  delete_kustomize "clusters/${CLUSTER}/layers/g0-bootstrap"
}

destroy_one() {
  case "$1" in
    g0) destroy_g0 ;;
    g1) destroy_g1 ;;
    g2) destroy_g2 ;;
    g3) destroy_g3 ;;
    g4) destroy_g4 ;;
    g5) destroy_g5 ;;
    g6) destroy_g6 ;;
    gitops) destroy_gitops ;;
    *) echo "Unknown layer: $1" && exit 1 ;;
  esac
}

if [[ "${LAYER}" == "all" ]]; then
  for layer in gitops g6 g5 g4 g3 g2 g1 g0; do
    destroy_one "${layer}"
  done
else
  destroy_one "${LAYER}"
fi

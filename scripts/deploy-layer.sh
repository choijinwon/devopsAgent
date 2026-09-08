#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-dev}"
KSERVE_VERSION="${KSERVE_VERSION:-v0.20.0}"
KSERVE_MODE="${KSERVE_MODE:-Standard}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.17.0}"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-v0.8.1}"
ARGO_WORKFLOWS_VERSION="${ARGO_WORKFLOWS_VERSION:-v4.1.2}"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
LAYER="${1:-all}"

apply_kustomize() {
  local path="$1"
  kubectl apply -k "${ROOT_DIR}/${path}"
}

deploy_g0() {
  apply_kustomize "clusters/${CLUSTER}/layers/g0-bootstrap"
}

deploy_g1() {
  apply_kustomize "clusters/${CLUSTER}/layers/g1-argocd"
  kubectl apply -n argocd --server-side --force-conflicts -f "${ARGOCD_MANIFEST_URL}"
  kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
  kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
  kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
}

deploy_g2() {
  apply_kustomize "clusters/${CLUSTER}/layers/g2-argo-workflows"
  kubectl apply -n argo --server-side --force-conflicts -f "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/install.yaml"
  kubectl -n argo rollout status deploy/workflow-controller --timeout=300s
  kubectl -n argo rollout status deploy/argo-server --timeout=300s
}

deploy_g3() {
  apply_kustomize "clusters/${CLUSTER}/layers/g3-buildkit"
  kubectl -n buildkit rollout status deploy/buildkitd --timeout=300s
}

deploy_g4() {
  apply_kustomize "clusters/${CLUSTER}/layers/g4-kserve-crds"
  kubectl apply --server-side --force-conflicts -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve-crds.yaml"
}

ensure_cert_manager() {
  if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
    kubectl apply --server-side --force-conflicts \
      -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
  fi
  kubectl -n cert-manager rollout status deploy/cert-manager --timeout=300s
  kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=300s
  kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=300s
}

ensure_metrics_server() {
  kubectl apply --server-side --force-conflicts \
    -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"
  if ! kubectl -n kube-system get deployment metrics-server \
    -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q -- '--kubelet-insecure-tls'; then
    kubectl -n kube-system patch deployment metrics-server --type=json \
      -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  fi
  kubectl -n kube-system rollout status deployment/metrics-server --timeout=300s
}

deploy_g5() {
  ensure_cert_manager
  ensure_metrics_server
  apply_kustomize "clusters/${CLUSTER}/layers/g5-kserve-controller"
  kubectl apply --server-side --force-conflicts -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve.yaml"
  if [[ "${KSERVE_MODE}" == "Standard" ]]; then
    kubectl -n kserve patch configmap inferenceservice-config --type merge -p '{"data":{"deploy":"{\"defaultDeploymentMode\":\"Standard\"}"}}'
  fi
  kubectl -n kserve rollout status deploy/kserve-controller-manager --timeout=300s
}

deploy_g6() {
  apply_kustomize "clusters/${CLUSTER}/layers/g6-kserve-runtimes"
  kubectl apply --server-side --force-conflicts -f "https://github.com/kserve/kserve/releases/download/${KSERVE_VERSION}/kserve-cluster-resources.yaml"
}

deploy_gitops() {
  local default_repo_url="https://github.com/choijinwon/devopsAgent.git"
  local repo_url="${GIT_REPO_URL:-${default_repo_url}}"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  cp -R "${ROOT_DIR}/clusters/${CLUSTER}/gitops-root/." "${tmp_dir}/"
  sed -i.bak "s#${default_repo_url}#${repo_url}#g" "${tmp_dir}"/*.yaml
  rm -f "${tmp_dir}"/*.bak
  kubectl apply -k "${tmp_dir}"
}

deploy_one() {
  case "$1" in
    g0) deploy_g0 ;;
    g1) deploy_g1 ;;
    g2) deploy_g2 ;;
    g3) deploy_g3 ;;
    g4) deploy_g4 ;;
    g5) deploy_g5 ;;
    g6) deploy_g6 ;;
    gitops) deploy_gitops ;;
    *) echo "Unknown layer: $1" && exit 1 ;;
  esac
}

if [[ "${LAYER}" == "all" ]]; then
  for layer in g0 g1 g2 g3 g4 g5 g6; do
    deploy_one "${layer}"
  done
else
  deploy_one "${LAYER}"
fi

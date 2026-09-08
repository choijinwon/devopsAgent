#!/usr/bin/env bash
set -euo pipefail

GIT_REPO_URL="${GIT_REPO_URL:-}"
GIT_REVISION="${GIT_REVISION:-main}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-${GIT_REVISION}}"
IMAGE_REPO="${IMAGE_REPO:-host.docker.internal:8080/library/layered-kserve}"
VERSION_SET="${VERSION_SET:-u24-cu128-py312-torch210-mlflow3152-kserve0190}"
LAYER="${LAYER:-all}"
PLATFORM="${PLATFORM:-linux/amd64}"

if [[ -z "${GIT_REPO_URL}" ]]; then
  echo "GIT_REPO_URL is required. Example: GIT_REPO_URL=https://github.com/org/repo.git make cicd-run" >&2
  exit 1
fi

validate_parameter() {
  local name="$1"
  local value="$2"
  if [[ ! "${value}" =~ ^[A-Za-z0-9._:/@-]+$ ]]; then
    echo "${name} contains unsupported characters: ${value}" >&2
    exit 1
  fi
}

validate_parameter GIT_REPO_URL "${GIT_REPO_URL}"
validate_parameter GIT_REVISION "${GIT_REVISION}"
validate_parameter DEPLOY_BRANCH "${DEPLOY_BRANCH}"
validate_parameter IMAGE_REPO "${IMAGE_REPO}"
validate_parameter VERSION_SET "${VERSION_SET}"
validate_parameter LAYER "${LAYER}"
validate_parameter PLATFORM "${PLATFORM}"

workflow_name="layered-model-cicd-$(date +%Y%m%d%H%M%S)"
kubectl create -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: ${workflow_name}
  namespace: argo
spec:
  workflowTemplateRef:
    name: layered-model-cicd
  arguments:
    parameters:
      - name: repo
        value: "${GIT_REPO_URL}"
      - name: revision
        value: "${GIT_REVISION}"
      - name: deployBranch
        value: "${DEPLOY_BRANCH}"
      - name: imageRepository
        value: "${IMAGE_REPO}"
      - name: versionSet
        value: "${VERSION_SET}"
      - name: layer
        value: "${LAYER}"
      - name: platform
        value: "${PLATFORM}"
EOF

echo "Workflow: ${workflow_name}"
echo "Watch: kubectl -n argo get workflow ${workflow_name} -w"

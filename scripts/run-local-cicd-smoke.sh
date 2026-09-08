#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_SET="${VERSION_SET:-u24-cu128-py312-torch210-mlflow3152-kserve0190}"
GIT_PORT="${GIT_PORT:-9418}"

version_file=""
for candidate in "${ROOT_DIR}"/versions/*.env; do
  if grep -q "^VERSION_SET=${VERSION_SET}$" "${candidate}"; then
    version_file="${candidate}"
    break
  fi
done
if [[ -z "${version_file}" ]]; then
  echo "Unknown version set: ${VERSION_SET}" >&2
  exit 1
fi

run_dir="$(mktemp -d /tmp/layered-cicd-run.XXXXXX)"
cleanup() {
  if [[ -n "${git_daemon_pid:-}" ]]; then
    kill "${git_daemon_pid}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

mkdir -p "${run_dir}/work/versions"
cp "${ROOT_DIR}/Dockerfile" "${run_dir}/work/Dockerfile"
cp "${version_file}" "${run_dir}/work/versions/$(basename "${version_file}")"
git -C "${run_dir}/work" init -b main >/dev/null
git -C "${run_dir}/work" config user.name "Local CI"
git -C "${run_dir}/work" config user.email "local-ci@localhost"
git -C "${run_dir}/work" add Dockerfile versions
git -C "${run_dir}/work" commit -m "Local g0 CI snapshot" >/dev/null
git clone --quiet --bare "${run_dir}/work" "${run_dir}/devops.git"

git daemon \
  --reuseaddr \
  --export-all \
  --base-path="${run_dir}" \
  --listen=0.0.0.0 \
  --port="${GIT_PORT}" \
  "${run_dir}" &
git_daemon_pid=$!
sleep 1

workflow_output="$({
  GIT_REPO_URL="git://host.docker.internal:${GIT_PORT}/devops.git" \
  GIT_REVISION=main \
  DEPLOY_BRANCH=main \
  LAYER=g0 \
  VERSION_SET="${VERSION_SET}" \
    "${ROOT_DIR}/scripts/run-cicd.sh"
})"
printf '%s\n' "${workflow_output}"
workflow_name="$(printf '%s\n' "${workflow_output}" | awk '/^Workflow:/ {print $2}')"

for _ in $(seq 1 180); do
  phase="$(kubectl -n argo get "workflow/${workflow_name}" -o jsonpath='{.status.phase}')"
  case "${phase}" in
    Succeeded|Failed|Error) break ;;
  esac
  sleep 5
done

kubectl -n argo get "workflow/${workflow_name}" \
  -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,STARTED:.status.startedAt,FINISHED:.status.finishedAt'
if [[ "${phase}" != Succeeded ]]; then
  build_pod="$(kubectl -n argo get pods \
    -l "workflows.argoproj.io/workflow=${workflow_name}" \
    -o jsonpath='{range .items[?(@.metadata.labels.workflows\.argoproj\.io/template=="build")]}{.metadata.name}{"\n"}{end}' | head -1)"
  if [[ -n "${build_pod}" ]]; then
    kubectl -n argo logs "${build_pod}" -c main --tail=100 || true
  fi
  exit 1
fi

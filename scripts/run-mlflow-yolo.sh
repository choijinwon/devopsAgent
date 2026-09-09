#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARBOR_SERVER="${HARBOR_SERVER:-host.docker.internal:8080}"
HARBOR_USERNAME="${HARBOR_USERNAME:-admin}"
HARBOR_PASSWORD_FILE="${HARBOR_PASSWORD_FILE:-${ROOT_DIR}/local/harbor/admin-password}"

if [[ -z "${HARBOR_PASSWORD:-}" && -f "${HARBOR_PASSWORD_FILE}" ]]; then
  HARBOR_PASSWORD="$(<"${HARBOR_PASSWORD_FILE}")"
fi
: "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD or provide local/harbor/admin-password}"

kubectl -n mlflow create configmap mlflow-yolo-code \
  --from-file=register_and_test.py="${ROOT_DIR}/examples/mlflow-yolo/register_and_test.py" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n mlflow create secret docker-registry harbor-pull \
  --docker-server="${HARBOR_SERVER}" \
  --docker-username="${HARBOR_USERNAME}" \
  --docker-password="${HARBOR_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

job_resource="$(kubectl create -f "${ROOT_DIR}/k8s/mlflow-yolo/job.yaml" -o name)"
job_name="${job_resource#job.batch/}"
echo "Created ${job_name}"
for _ in $(seq 1 360); do
  succeeded="$(kubectl -n mlflow get "job/${job_name}" -o jsonpath='{.status.succeeded}')"
  failed="$(kubectl -n mlflow get "job/${job_name}" -o jsonpath='{.status.failed}')"
  if [[ "${succeeded:-0}" -gt 0 ]]; then
    kubectl -n mlflow logs "job/${job_name}"
    exit 0
  fi
  if [[ "${failed:-0}" -gt 0 ]]; then
    kubectl -n mlflow logs "job/${job_name}" >&2
    exit 1
  fi
  sleep 5
done

echo "Timed out waiting for ${job_name}" >&2
kubectl -n mlflow logs "job/${job_name}" >&2 || true
exit 1

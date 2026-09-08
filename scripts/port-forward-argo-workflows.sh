#!/usr/bin/env bash
set -euo pipefail

ARGO_WORKFLOWS_LOCAL_PORT="${ARGO_WORKFLOWS_LOCAL_PORT:-2746}"

echo "Argo Workflows UI: https://127.0.0.1:${ARGO_WORKFLOWS_LOCAL_PORT}"
kubectl -n argo port-forward deployment/argo-server \
  "${ARGO_WORKFLOWS_LOCAL_PORT}:2746" \
  --address 127.0.0.1

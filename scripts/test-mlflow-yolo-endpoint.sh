#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8082}"
ENDPOINT="http://127.0.0.1:${PORT}/v1/models/yolo11n-detector:predict"
LOG_FILE="${TMPDIR:-/tmp}/yolo11n-detector-port-forward.log"

kubectl -n model-serving port-forward \
  service/yolo11n-detector-predictor "${PORT}:80" \
  --address 127.0.0.1 >"${LOG_FILE}" 2>&1 &
port_forward_pid=$!
trap 'kill "${port_forward_pid}" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
  if curl --silent --fail "http://127.0.0.1:${PORT}/v1/models/yolo11n-detector" >/dev/null; then
    break
  fi
  sleep 1
done

curl --fail-with-body --silent --show-error \
  --request POST \
  --header 'Content-Type: application/json' \
  --data '{"instances":[{"image":"https://ultralytics.com/images/bus.jpg"}],"parameters":{"confidence":0.25}}' \
  "${ENDPOINT}"
printf '\n'

#!/usr/bin/env sh
set -eu

case "${1:-}" in
  g0) echo "g0-ubuntu" ;;
  g1) echo "g1-cuda" ;;
  g2) echo "g2-python" ;;
  g3) echo "g3-pytorch" ;;
  g4) echo "g4-mlflow" ;;
  g5) echo "g5-kserve" ;;
  g6) echo "g6-id" ;;
  *) echo "unknown layer: ${1:-}" >&2; exit 1 ;;
esac

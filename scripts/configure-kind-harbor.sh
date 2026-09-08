#!/usr/bin/env bash
set -euo pipefail

KIND_NODE="${KIND_NODE:-devops-control-plane}"
HARBOR_SERVER="${HARBOR_SERVER:-host.docker.internal:8080}"

if [[ ! "${KIND_NODE}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "KIND_NODE contains unsupported characters: ${KIND_NODE}" >&2
  exit 1
fi
if [[ ! "${HARBOR_SERVER}" =~ ^[A-Za-z0-9._:-]+$ ]]; then
  echo "HARBOR_SERVER contains unsupported characters: ${HARBOR_SERVER}" >&2
  exit 1
fi
if ! docker inspect "${KIND_NODE}" >/dev/null 2>&1; then
  echo "kind node container not found: ${KIND_NODE}" >&2
  exit 1
fi

registry_dir="/etc/containerd/certs.d/${HARBOR_SERVER}"
docker exec "${KIND_NODE}" mkdir -p "${registry_dir}"
docker exec -i "${KIND_NODE}" sh -c "tee '${registry_dir}/hosts.toml' >/dev/null" <<EOF
server = "http://${HARBOR_SERVER}"

[host."http://${HARBOR_SERVER}"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF

echo "Configured ${KIND_NODE} to pull from http://${HARBOR_SERVER}."

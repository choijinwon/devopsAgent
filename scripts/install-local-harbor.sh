#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARBOR_VERSION="${HARBOR_VERSION:-v2.15.2}"
HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-localhost}"
HARBOR_HTTP_PORT="${HARBOR_HTTP_PORT:-8080}"
HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD:-Harbor12345}"
HARBOR_INSTALL_ROOT="${HARBOR_INSTALL_ROOT:-${ROOT_DIR}/local/harbor}"
HARBOR_PASSWORD_FILE="${HARBOR_PASSWORD_FILE:-${HARBOR_INSTALL_ROOT}/admin-password}"
HARBOR_DATA_VOLUME="${HARBOR_DATA_VOLUME:-${ROOT_DIR}/data/harbor}"
HARBOR_WITH_TRIVY="${HARBOR_WITH_TRIVY:-false}"

installer_name="harbor-online-installer-${HARBOR_VERSION}.tgz"
installer_url="https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/${installer_name}"
download_dir="${HARBOR_INSTALL_ROOT}/downloads"
extract_dir="${HARBOR_INSTALL_ROOT}/${HARBOR_VERSION}"
harbor_dir="${extract_dir}/harbor"

mkdir -p "${download_dir}" "${extract_dir}" "${HARBOR_DATA_VOLUME}"

if [[ ! -f "${download_dir}/${installer_name}" ]]; then
  curl -fL "${installer_url}" -o "${download_dir}/${installer_name}"
fi

if [[ ! -f "${harbor_dir}/install.sh" ]]; then
  tar -xzf "${download_dir}/${installer_name}" -C "${extract_dir}"
fi

cd "${harbor_dir}"
cp harbor.yml.tmpl harbor.yml

python3 - <<PY
from pathlib import Path

path = Path("harbor.yml")
text = path.read_text()
text = text.replace("hostname: reg.mydomain.com", "hostname: ${HARBOR_HOSTNAME}")
text = text.replace("  port: 80", "  port: ${HARBOR_HTTP_PORT}", 1)
text = text.replace("harbor_admin_password: Harbor12345", "harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}")
text = text.replace("data_volume: /data", "data_volume: ${HARBOR_DATA_VOLUME}")

lines = text.splitlines()
out = []
in_https = False
for line in lines:
    if line.startswith("https:"):
        in_https = True
        out.append("# " + line)
        continue
    if in_https:
        if line and not line.startswith(" ") and not line.startswith("#"):
            in_https = False
        else:
            out.append("# " + line if line else line)
            continue
    out.append(line)

path.write_text("\\n".join(out) + "\\n")
PY

if [[ "${HARBOR_WITH_TRIVY}" == "true" ]]; then
  ./install.sh --with-trivy
else
  ./install.sh
fi

umask 077
printf '%s\n' "${HARBOR_ADMIN_PASSWORD}" > "${HARBOR_PASSWORD_FILE}"

echo "Harbor is installed at http://${HARBOR_HOSTNAME}:${HARBOR_HTTP_PORT}"
echo "Username: admin"
echo "Password file: ${HARBOR_PASSWORD_FILE}"

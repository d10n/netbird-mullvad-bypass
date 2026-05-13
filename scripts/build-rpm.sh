#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
fedora_version="${FEDORA_VERSION:-latest}"
image_name="netbird-mullvad-rpm-builder"
if [[ "${fedora_version}" == "latest" ]]; then
    image_tag="latest"
else
    image_tag="fc${fedora_version}"
fi
container_name="rpm-build-$$"

CONTAINER_CMD="${CONTAINER_CMD:-}"
if [[ -z "${CONTAINER_CMD}" ]]; then
    if command -v podman &>/dev/null; then
        CONTAINER_CMD=podman
    elif command -v docker &>/dev/null; then
        CONTAINER_CMD=docker
    else
        echo >&2 "==> Error: neither docker nor podman found"
        exit 1
    fi
fi
echo "==> Using ${CONTAINER_CMD}"

# Build the container image if it doesn't exist
if ! ${CONTAINER_CMD} image inspect "${image_name}:${image_tag}" >/dev/null 2>&1; then
    echo "==> Building build image ${image_name}:${image_tag} (Fedora ${fedora_version})..."
    ${CONTAINER_CMD} build \
        --build-arg fedora_version="${fedora_version}" \
        -f "${project_dir}/containers/rpm.Containerfile" \
        -t "${image_name}:${image_tag}" \
        "${project_dir}"
fi

# Run the build in a container, mounting workspace for output
echo "==> Building RPM in container..."

# Podman needs :Z for SELinux relabeling on mounted volumes
volume_opts="rw"
if [[ "${CONTAINER_CMD}" == podman ]]; then
    volume_opts="rw,Z"
fi

${CONTAINER_CMD} run --rm \
    --name "${container_name}" \
    -v "${project_dir}:/output:${volume_opts}" \
    "${image_name}:${image_tag}" \
    bash -c '
        mkdir -p /output/dist
        cp -a /output/. /build/
        cd /build && make rpm
        cp -a /build/dist/*.rpm /output/dist/
    '

echo "==> RPMs built:"
ls -lh "${project_dir}/dist"/*.rpm 2>/dev/null || echo "  (none found)"

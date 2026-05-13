#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
debian_version="${DEBIAN_VERSION:-latest}"
image_name="netbird-mullvad-deb-builder"
if [[ "${debian_version}" == "latest" || "${debian_version}" == "unstable" ]]; then
    image_tag="latest"
else
    image_tag="${debian_version}"
fi
container_name="deb-build-$$"

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
    echo "==> Building build image ${image_name}:${image_tag} (Debian ${debian_version})..."
    ${CONTAINER_CMD} build \
        --build-arg debian_version="${debian_version}" \
        -f "${project_dir}/containers/deb.Containerfile" \
        -t "${image_name}:${image_tag}" \
        "${project_dir}"
fi

# Run the build in a container, mounting workspace for output
echo "==> Building .deb in container..."

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
        cd /build && make deb
        cp -a /build/build/deb/*.deb /output/dist/
    '

echo "==> .debs built:"
ls -lh "${project_dir}/dist"/*.deb 2>/dev/null || echo "  (none found)"

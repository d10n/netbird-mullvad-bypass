#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
image_name="netbird-mullvad-arch-builder"
image_tag="latest"
container_name="arch-build-$$"

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
    echo "==> Building build image ${image_name}:${image_tag}..."
    ${CONTAINER_CMD} build \
        -f "${project_dir}/containers/arch.Containerfile" \
        -t "${image_name}:${image_tag}" \
        "${project_dir}"
fi

# Run the build in a container, mounting workspace for output
echo "==> Building Arch package in container..."

# Podman needs :Z for SELinux relabeling on mounted volumes
volume_opts="rw"
if [[ "${CONTAINER_CMD}" == podman ]]; then
    volume_opts="rw,Z"
fi

# makepkg refuses to run as root, so drop privileges to the `builder` user
# baked into the image before invoking the Make target.
${CONTAINER_CMD} run --rm \
    --name "${container_name}" \
    -v "${project_dir}:/output:${volume_opts}" \
    "${image_name}:${image_tag}" \
    bash -c '
        mkdir -p /output/dist
        cp -a /output/. /build/
        chown -R builder:builder /build
        su builder -c "cd /build && make arch"
        cp -a /build/dist/*.pkg.tar.zst /output/dist/
    '

echo "==> Arch packages built:"
ls -lh "${project_dir}/dist"/*.pkg.tar.zst 2>/dev/null || echo "  (none found)"

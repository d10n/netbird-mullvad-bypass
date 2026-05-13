FROM ghcr.io/archlinux/archlinux:base-devel

# `git` is unused by `make arch` itself but matches the dependency set the
# release workflow has historically installed; `sudo` is already in base-devel.
RUN pacman -Syu --noconfirm --needed git make sudo && \
    pacman -Scc --noconfirm && \
    useradd -m builder

WORKDIR /build

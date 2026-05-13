ARG fedora_version=41
FROM registry.fedoraproject.org/fedora:${fedora_version}

RUN dnf install -y rpm-build systemd-rpm-macros make tar gzip bzip2 && \
    dnf clean all

WORKDIR /build

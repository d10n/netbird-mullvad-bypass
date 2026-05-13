ARG debian_version=bookworm
FROM mirror.gcr.io/library/debian:${debian_version}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential dpkg-dev debhelper-compat devscripts make && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

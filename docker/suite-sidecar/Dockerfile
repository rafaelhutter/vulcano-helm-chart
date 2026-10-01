# Suite Studios FUSE client, run as a native sidecar next to vulcano.
FROM ubuntu:24.04

ARG SUITE_VERSION=67.702.0
# The download URL is unversioned; the checksum pins the release and fails the build on drift.
ARG SUITE_SHA256=a52a496d3479f4de8d60e6cecd32ffe7b765804d5468160f443db2144d0f33ea
ARG SUITE_URL=https://saturn-installer-prd-124359286071-bucket.s3-accelerate.amazonaws.com/suite-installer-ubuntu-x64.deb

LABEL org.opencontainers.image.title="suite-sidecar" \
      org.opencontainers.image.version="${SUITE_VERSION}"

# libicu: .NET CLI aborts without it; postinst calls sudo; user_allow_other enables FUSE_ALLOW_OTHER.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl libicu74 sudo tini util-linux procps \
 && curl -fsSL -o /tmp/suite.deb "${SUITE_URL}" \
 && echo "${SUITE_SHA256}  /tmp/suite.deb" | sha256sum -c - \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends /tmp/suite.deb \
 && echo user_allow_other > /etc/fuse.conf \
 && rm -rf /tmp/suite.deb /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh

ENV HOME=/root
# tini reaps the daemonized suitefs; no -g so SIGTERM reaches only the entrypoint's trap.
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Stage 1: pull a standalone Python interpreter via uv.
# We need Python 3.5+ to run nzbhydra2's wrapper script (stdlib-only, no
# venv/pip needed). uv ships a single static binary and can materialise a
# self-contained CPython into /opt/python which we then copy into the final
# image — no apt python3 install, no system-wide pollution.
# Build on the same glibc base as the final stage so the standalone Python
# is glibc-linked (uv-musl Python wouldn't run on a glibc ubuntu image).
FROM ghcr.io/ipromknight/ubuntu:rolling AS python-fetch

ARG TARGETARCH

USER root

RUN apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
        amd64) UV_TRIPLE=x86_64-unknown-linux-gnu ;; \
        arm64) UV_TRIPLE=aarch64-unknown-linux-gnu ;; \
        *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/0.11.14/uv-${UV_TRIPLE}.tar.gz" -o /tmp/uv.tar.gz && \
    tar -xzf /tmp/uv.tar.gz -C /tmp && \
    mv "/tmp/uv-${UV_TRIPLE}/uv" /usr/local/bin/uv && \
    rm -rf /tmp/uv.tar.gz "/tmp/uv-${UV_TRIPLE}"

ENV UV_PYTHON_INSTALL_DIR=/opt/python

# Install Python 3.12 and stage it under stable paths /opt/python/bin/python3
# so the wrapper finds it on PATH regardless of uv's internal layout (which
# uses cpython-X.Y.Z-<triple>/ dirs that can change between uv versions).
# We `mv` the whole interpreter tree to /opt/python-runtime (preserves lib/
# include/ share/ etc.) then create our own /opt/python with stable bin/.
RUN uv python install 3.12 \
    && PY_REAL=$(readlink -f "$(uv python find 3.12)") \
    && PY_ROOT=$(dirname $(dirname "$PY_REAL")) \
    && mv "$PY_ROOT" /opt/python-runtime \
    && rm -rf /opt/python \
    && mv /opt/python-runtime /opt/python \
    && ln -sf python3.12 /opt/python/bin/python3 \
    && ln -sf python3.12 /opt/python/bin/python \
    && /opt/python/bin/python3 --version

# Stage 2: final runtime image.
FROM ghcr.io/ipromknight/ubuntu:rolling

ARG TARGETPLATFORM
ARG VERSION
ARG CHANNEL

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# `core` bundles its own JRE so we don't install OpenJDK. `unzip` for the
# release archive; `libfreetype6` is needed at runtime by the embedded JRE
# when nzbhydra2 renders certain UI assets.
# hadolint ignore=DL3008
RUN \
    apt-get -qq update \
    && apt-get -qq install -y --no-install-recommends \
        ca-certificates \
        curl \
        libfreetype6 \
        unzip \
    && \
    case "${TARGETPLATFORM}" in \
        'linux/amd64') export ARCH='amd64' ;; \
        'linux/arm64') export ARCH='arm64' ;; \
        *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac \
    && \
    ASSET_URL="https://github.com/theotherp/nzbhydra2/releases/download/v${VERSION}/nzbhydra2-${VERSION}-${ARCH}-linux.zip" \
    && \
    mkdir -p /app \
    && curl -fsSL "${ASSET_URL}" -o /tmp/nzbhydra2.zip \
    && unzip -q /tmp/nzbhydra2.zip -d /app \
    && \
    # nzbhydra2wrapperPy3.py is the canonical entrypoint — handles core's
    # control-code restart loop (exit 22 from in-UI restart, 33 for restore,
    # 1/99 with crash-loop guard) and reads xmx / customVmOptions from
    # /config/nzbhydra.yml so the user can tune the JVM from the web UI.
    # readme.md must stay on disk: core uses its presence as a base-path
    # sanity check and refuses to run without it.
    rm -rf \
        /app/rc.d \
        /app/systemd \
        /app/sysv \
        /app/upstart \
        /app/nzbhydra2wrapper.py \
        /app/changelog.md \
        /tmp/nzbhydra2.zip \
    && chmod +x /app/core /app/nzbhydra2wrapperPy3.py \
    && chown -R 568:568 /app \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Bring in the standalone Python from the fetch stage.
COPY --from=python-fetch --chown=568:568 /opt/python /opt/python
ENV PATH="/opt/python/bin:${PATH}"

EXPOSE 5076
VOLUME ["/config"]

USER 568

COPY --chmod=0755 ./apps/nzbhydra2/promknight-entrypoint.sh /promknight-entrypoint.sh

LABEL org.opencontainers.image.title="NZBHydra2"
LABEL org.opencontainers.image.source="https://github.com/theotherp/nzbhydra2"

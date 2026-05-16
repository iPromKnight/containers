# Stage 0: shallow-clone the release tag of proton-gluetun-updater.
# Pattern follows decypharr / houndarr — Tag-based clone via $VERSION.
FROM alpine AS cloner
ARG VERSION
RUN apk add --update --no-cache git && \
    git clone -b $VERSION https://github.com/iPromKnight/proton-gluetun-updater.git /source

# xx provides cross-compilation toolchains for the Go build.
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

# Stage 1: build the Go binary. Pinned to BUILDPLATFORM so the Go toolchain
# runs natively (fast) while emitting a binary for TARGET{OS,ARCH}.
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TARGETPLATFORM
ARG VERSION=0.0.0
ARG CHANNEL=dev

COPY --from=xx / /

WORKDIR /app

# Plain cross-compile — the project is CGO-free, so no toolchain install needed.
COPY --from=cloner /source/go.mod /source/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

COPY --from=cloner /source/. .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath \
    -ldflags="-w -s -X main.version=${VERSION}" \
    -o /updater ./cmd/updater && \
    xx-verify /updater

# Stage 2: build the Python venv containing proton-core for auth_helper.py.
# Build on the same base as runtime so musl-linked wheels match at runtime.
# (No --platform pin needed — buildx defaults non-first stages to TARGETPLATFORM,
#  which is exactly what we want.)
FROM ghcr.io/ipromknight/alpine:rolling AS python-build

USER root

# uv brings its own Python interpreter, but it still needs `git` to resolve
# git+https:// references (proton-core is published only via git tags, no
# wheels on PyPI). build-base + libffi/openssl headers are for the few wheels
# that compile from source on musl (cryptography, bcrypt).
RUN apk add --no-cache \
    ca-certificates curl git build-base libffi-dev openssl-dev python3-dev

# Pin uv version for reproducibility. Standalone binary, no Python needed to install it.
RUN curl -fsSL "https://github.com/astral-sh/uv/releases/download/0.11.14/uv-x86_64-unknown-linux-musl.tar.gz" -o /tmp/uv.tar.gz && \
    tar -xzf /tmp/uv.tar.gz -C /tmp && \
    mv /tmp/uv-x86_64-unknown-linux-musl/uv /usr/local/bin/uv && \
    rm -rf /tmp/uv.tar.gz /tmp/uv-x86_64-unknown-linux-musl

ENV UV_PYTHON_INSTALL_DIR=/opt/python

# uv downloads a standalone Python 3.12 into /opt/python, creates a venv at
# /opt/venv pointing at it, and installs proton-core (the only runtime dep
# for auth_helper.py). Pin the proton-core ref to match upstream's pin.
RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    uv venv --python 3.12 /opt/venv && \
    uv pip install --python /opt/venv/bin/python --no-cache-dir \
        "proton-core @ git+https://github.com/ProtonVPN/python-proton-core.git@v0.7.0"

# Stage 3: final runtime image — alpine base with the entrypoint chain.
FROM ghcr.io/ipromknight/alpine:rolling

ARG VERSION=0.0.0
ARG CHANNEL=dev

LABEL version="${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source="https://github.com/iPromKnight/proton-gluetun-updater"
LABEL org.opencontainers.image.title="proton-gluetun-updater"
LABEL org.opencontainers.image.authors="iPromKnight"
LABEL org.opencontainers.image.documentation="https://github.com/iPromKnight/proton-gluetun-updater/blob/main/README.md"
LABEL org.opencontainers.image.licenses="MIT"

USER root

# proton-core's SRP flow verifies the modulus by checking its detached PGP
# signature, which shells out to `gpg`. Without this, every auth attempt fails
# with `OSError: Unable to run gpg (gpg) - it may not be available.`
RUN apk add --no-cache gnupg

# Bring in the standalone Python interpreter (for the auth helper) and the
# venv with proton-core already installed. /opt is owned by notroot so the
# helper can be invoked without root.
COPY --from=python-build --chown=568:568 /opt/python /opt/python
COPY --from=python-build --chown=568:568 /opt/venv   /opt/venv

# Application binary and the Python sidecar.
COPY --from=builder --chown=568:568 /updater                /app/updater
COPY --from=cloner  --chown=568:568 /source/auth_helper.py  /app/auth_helper.py

# /gluetun is the storage path — mode 0700 keeps the session token + WG keys
# private to notroot. /config kept for parity with other promknight apps.
RUN install -d -o 568 -g 568 -m 0700 /gluetun && \
    chown -R 568:568 /app

# Env-var contract documented at:
#   https://github.com/iPromKnight/proton-gluetun-updater/blob/main/README.md
ENV STORAGE_FILEPATH=/gluetun \
    WEB_HOST=0.0.0.0 \
    WEB_PORT=8080 \
    AUTH_HELPER_PATH=/app/auth_helper.py \
    PYTHON_BIN=/opt/venv/bin/python

EXPOSE 8080
VOLUME ["/gluetun"]

USER 568

COPY --chmod=0755 apps/proton-gluetun-updater/promknight-entrypoint.sh /promknight-entrypoint.sh

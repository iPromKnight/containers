FROM alpine AS cloner
ARG VERSION
RUN apk add --update --no-cache git && \
    git clone -b $VERSION https://github.com/av1155/houndarr.git /source

# Stage 1: build the Tailwind CSS bundle (node only)
FROM --platform=$BUILDPLATFORM node:22-alpine AS css-build
WORKDIR /build
RUN corepack enable

COPY --from=cloner /source/package.json /source/pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
    pnpm install --frozen-lockfile

COPY --from=cloner /source/src/houndarr/static/css/ ./src/houndarr/static/css/
COPY --from=cloner /source/src/houndarr/templates/  ./src/houndarr/templates/

RUN pnpm run build-css

# Stage 2: build the Python venv (Python 3.13 from deadsnakes on Focal)
# Doing the heavy lifting in a builder so the runtime image stays tidy.
FROM --platform=$BUILDPLATFORM ubuntu:20.04 AS python-build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common ca-certificates gnupg curl && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.13 python3.13-venv python3.13-dev \
        build-essential libffi-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=cloner /source/pyproject.toml /source/uv.lock /source/VERSION /source/hatch_build.py ./

# Create a Python 3.13 virtualenv, install uv into it, then export and pip-install
# the resolved deps. Wheel-only install keeps build time short.
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    python3.13 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip uv && \
    /opt/venv/bin/uv export --frozen --no-hashes --no-emit-project --no-dev -o /tmp/requirements.txt && \
    /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Final stage — your base image with its entrypoint chain
FROM ghcr.io/ipromknight/ubuntu:rolling

ARG VERSION=0.0.0
ARG CHANNEL=dev
ARG DEBIAN_FRONTEND=noninteractive

LABEL version="${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source="https://github.com/av1155/houndarr"
LABEL org.opencontainers.image.title="houndarr"
LABEL org.opencontainers.image.authors="av1155"
LABEL org.opencontainers.image.documentation="https://github.com/av1155/houndarr/blob/main/README.md"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common ca-certificates gnupg && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.13 python3.13-venv libpython3.13 curl && \
    apt-get remove -y software-properties-common gnupg && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/src \
    HOUNDARR_VERSION="${VERSION}" \
    HOUNDARR_DATA_DIR=/data \
    PATH="/opt/venv/bin:${PATH}"

WORKDIR /app

COPY --from=python-build --chown=568:568 /opt/venv                    /opt/venv
COPY --from=cloner       --chown=568:568 /source/src/                 ./src/
COPY --from=cloner       --chown=568:568 /source/VERSION              ./
COPY --from=cloner       --chown=568:568 /source/CHANGELOG.md         ./
COPY --from=css-build    --chown=568:568 /build/src/houndarr/static/css/app.built.css \
                                          ./src/houndarr/static/css/app.built.css

RUN install -d -o 568 -g 568 /data /config && \
    chown -R 568:568 /app

EXPOSE 8877
VOLUME ["/data"]

USER 568

COPY --chmod=0755 apps/houndarr/promknight-entrypoint.sh /promknight-entrypoint.sh
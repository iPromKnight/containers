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

# Stage 2: build the Python venv using uv's standalone Python
FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS python-build

ARG DEBIAN_FRONTEND=noninteractive

# uv handles the Python install itself — we just need curl + ca-certs + build tools
# (for wheels that compile from source: cryptography, bcrypt, etc.)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl build-essential libffi-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Pin uv version for reproducibility. Standalone binary, no python required to install.
ADD https://github.com/astral-sh/uv/releases/download/0.5.13/uv-x86_64-unknown-linux-gnu.tar.gz /tmp/uv.tar.gz
RUN tar -xzf /tmp/uv.tar.gz -C /tmp && \
    mv /tmp/uv-x86_64-unknown-linux-gnu/uv /usr/local/bin/uv && \
    rm -rf /tmp/uv.tar.gz /tmp/uv-x86_64-unknown-linux-gnu

WORKDIR /app

COPY --from=cloner /source/pyproject.toml /source/VERSION /source/requirements.txt ./

# uv installs Python 3.12 standalone into the venv it creates, then installs deps.
# UV_PYTHON_INSTALL_DIR pins where the interpreter lives so we can copy it later.
ENV UV_PYTHON_INSTALL_DIR=/opt/python

RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    uv venv --python 3.12 /opt/venv && \
    uv pip install --python /opt/venv/bin/python --no-cache-dir -r requirements.txt

# Final stage — your base image with its entrypoint chain
FROM ghcr.io/ipromknight/ubuntu:rolling

ARG VERSION=0.0.0
ARG CHANNEL=dev

LABEL version="${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source="https://github.com/av1155/houndarr"
LABEL org.opencontainers.image.title="houndarr"
LABEL org.opencontainers.image.authors="av1155"
LABEL org.opencontainers.image.documentation="https://github.com/av1155/houndarr/blob/main/README.md"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

# Runtime only needs curl for healthcheck — the Python interpreter is bundled
# inside /opt/python from the standalone build.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/src \
    HOUNDARR_VERSION="${VERSION}" \
    HOUNDARR_DATA_DIR=/data \
    PATH="/opt/venv/bin:${PATH}"

WORKDIR /app


# Bring in the standalone Python interpreter, the venv (with all houndarr deps),
# and the houndarr source.
COPY --from=python-build --chown=568:568 /opt/python                  /opt/python
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
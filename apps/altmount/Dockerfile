FROM alpine AS cloner
ARG VERSION
# VERSION is "dev-<short-sha>" produced by ci/latest.sh; check out that commit.
RUN apk add --update --no-cache git && \
    git clone https://github.com/javi11/altmount.git /source && \
    git -C /source checkout "${VERSION#dev-}"

# xx provides cross-compilation toolchains for CGO builds
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

# Frontend build stage — bun, native (frontend is platform-agnostic JS)
FROM --platform=$BUILDPLATFORM oven/bun:1 AS frontend-builder
WORKDIR /app/frontend
COPY --from=cloner /source/frontend/bun.lock /source/frontend/package.json ./
RUN --mount=type=cache,target=/root/.bun/install/cache,sharing=locked \
    bun install --frozen-lockfile
COPY --from=cloner /source/frontend/. .
RUN --mount=type=cache,target=/tmp/bun-build-cache,sharing=locked \
    bun run build

# Backend build — pinned to BUILDPLATFORM so Go runs natively (fast)
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TARGETPLATFORM
ARG VERSION=0.0.0
ARG CHANNEL=dev
ARG COMMIT=unknown
ARG BUILD_TIMESTAMP=unknown

COPY --from=xx / /
WORKDIR /app

# Cross-compilation toolchain + sqlite headers (altmount uses CGO + sqlite)
RUN apk add --no-cache clang lld && \
    xx-apk add --no-cache gcc g++ musl-dev libc-dev sqlite-dev sqlite-static fuse-dev

COPY --from=cloner /source/go.mod /source/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

COPY --from=cloner /source/. .

# Frontend assets embedded into the binary
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Build the static binary — matches upstream's static-link flags
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=1 \
    xx-go build -trimpath \
    -ldflags="-linkmode external -extldflags '-static' -w -s \
              -X 'github.com/javi11/altmount/internal/version.Version=${VERSION}' \
              -X 'github.com/javi11/altmount/internal/version.GitCommit=${COMMIT}' \
              -X 'github.com/javi11/altmount/internal/version.Timestamp=${BUILD_TIMESTAMP}'" \
    -o /altmount cmd/altmount/main.go && \
    xx-verify /altmount

# Static rclone binary
FROM alpine:latest AS rclone-extractor
ARG TARGETARCH
WORKDIR /tmp
RUN apk add --no-cache curl unzip && \
    case "$TARGETARCH" in \
        amd64) ARCH=amd64 ;; \
        arm64) ARCH=arm64 ;; \
        arm)   ARCH=arm   ;; \
        *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -L "https://downloads.rclone.org/rclone-current-linux-${ARCH}.zip" -o rclone.zip && \
    unzip rclone.zip && \
    cp rclone-*/rclone /rclone && \
    chmod +x /rclone

# Directory scaffold
FROM alpine:3.19 AS dirsetup
RUN mkdir -p /app/logs /config/metadata && \
    chmod 777 /app/logs && \
    touch /app/logs/altmount.log && \
    chmod 666 /app/logs/altmount.log

# Final image
FROM ghcr.io/ipromknight/alpine:rolling

ARG VERSION=0.0.0
ARG CHANNEL=dev

LABEL version="${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source="https://github.com/javi11/altmount"
LABEL org.opencontainers.image.title="altmount"
LABEL org.opencontainers.image.authors="javi11"
LABEL org.opencontainers.image.documentation="https://altmount.kipsilabs.top/"

# fuse3 runtime + mime types (altmount serves WebDAV with content-types)
RUN apk add --no-cache fuse3 mailcap && \
    ln -sf /usr/bin/fusermount3 /usr/bin/fusermount && \
    echo "user_allow_other" >> /etc/fuse.conf

# Binaries
COPY --from=builder           --chown=568:568 /altmount /usr/bin/altmount
COPY --from=rclone-extractor  --chown=568:568 /rclone   /usr/local/bin/rclone
COPY --from=dirsetup          --chown=568:568 /app      /app
COPY --from=dirsetup          --chown=568:568 /config   /config

# Frontend (served from /app/frontend/dist by altmount at runtime)
COPY --from=frontend-builder  --chown=568:568 /app/frontend/dist /app/frontend/dist

ENV LOG_PATH=/config/logs
ENV PORT=8080
ENV HOST=0.0.0.0
EXPOSE 8080

USER 568

# Seed config for goss/web tests
COPY --chown=568:568 apps/altmount/config.yaml /config/config.yaml

COPY --chmod=0755 apps/altmount/promknight-entrypoint.sh /promknight-entrypoint.sh
FROM alpine AS cloner
ARG VERSION
RUN apk add --update --no-cache tmux ttyd git && \
    git clone -b $VERSION https://github.com/sirrobot01/decypharr.git /source

# xx provides cross-compilation toolchains for CGO builds
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

# Stage 1: Build binaries — pinned to BUILDPLATFORM so Go runs natively (fast)
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TARGETPLATFORM
ARG VERSION=0.0.0
ARG CHANNEL=dev

# Copy xx scripts for cross-compilation
COPY --from=xx / /

WORKDIR /app

# Install cross-compilation toolchain via xx
RUN apk add --no-cache clang lld && \
    xx-apk add --no-cache gcc g++ musl-dev libc-dev fuse-dev

COPY --from=cloner /source/go.mod /source/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

COPY --from=cloner /source/. .

# Build main binary — xx-go sets CC/CXX/GOOS/GOARCH automatically
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=1 \
    xx-go build -trimpath \
    -ldflags="-w -s -X github.com/sirrobot01/decypharr/pkg/version.Version=${VERSION} -X github.com/sirrobot01/decypharr/pkg/version.Channel=${CHANNEL}" \
    -o /decypharr && \
    xx-verify /decypharr

# Build healthcheck (no CGO needed, plain cross-compile)
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-w -s" \
    -o /healthcheck cmd/healthcheck/main.go

# Stage 1.5: Download static ffprobe binary
FROM alpine:latest AS ffprobe-extractor
ARG TARGETARCH
WORKDIR /tmp
RUN apk add --no-cache curl unzip && \
    case "$TARGETARCH" in \
        amd64) PLATFORM="linux-64" ;; \
        arm64) PLATFORM="linux-arm-64" ;; \
        *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -L "https://github.com/ffbinaries/ffbinaries-prebuilt/releases/download/v6.1/ffprobe-6.1-${PLATFORM}.zip" -o ffprobe.zip && \
    unzip ffprobe.zip && \
    chmod +x ffprobe && \
    mv ffprobe /ffprobe

# Stage 1.6: Download static rclone binary
FROM alpine:latest AS rclone-extractor
ARG TARGETARCH
WORKDIR /tmp
RUN apk add --no-cache curl unzip && \
    case "$TARGETARCH" in \
        amd64) ARCH=amd64 ;; \
        arm64) ARCH=arm64 ;; \
        arm) ARCH=arm ;; \
        *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -L "https://downloads.rclone.org/rclone-current-linux-${ARCH}.zip" -o rclone.zip && \
    unzip rclone.zip && \
    cp rclone-*/rclone /rclone && \
    chmod +x /rclone

# Stage 2: Create directory structure
FROM alpine:3.19 AS dirsetup
RUN mkdir -p /app/logs && \
    mkdir -p /app/cache && \
    chmod 777 /app/logs && \
    touch /app/logs/decypharr.log && \
    chmod 666 /app/logs/decypharr.log

# Stage 3: Final image
FROM ghcr.io/ipromknight/alpine:rolling

ARG VERSION=0.0.0
ARG CHANNEL=dev

LABEL version="${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source="https://github.com/sirrobot01/decypharr"
LABEL org.opencontainers.image.title="decypharr"
LABEL org.opencontainers.image.authors="sirrobot01"
LABEL org.opencontainers.image.documentation="https://github.com/sirrobot01/decypharr/blob/main/README.md"

# fuse3 runtime is required now that decypharr links libfuse
RUN apk add --no-cache fuse3 && \
    echo "user_allow_other" >> /etc/fuse.conf

# Copy binaries
COPY --from=builder --chown=568:568 /decypharr /usr/bin/decypharr
COPY --from=builder --chown=568:568 /healthcheck /usr/bin/healthcheck
COPY --from=ffprobe-extractor --chown=568:568 /ffprobe /usr/bin/ffprobe
COPY --from=rclone-extractor --chown=568:568 /rclone /usr/local/bin/rclone

# Copy pre-made directory structure
COPY --from=dirsetup --chown=568:568 /app /app

# Metadata
ENV LOG_PATH=/config/logs
EXPOSE 8282

USER 568

# So that the app will start for goss tests
COPY --chown=568:568 apps/decypharr/config.json /config/

COPY --chmod=0755 apps/decypharr/promknight-entrypoint.sh /promknight-entrypoint.sh
FROM alpine AS cloner
ARG VERSION
RUN apk add --update --no-cache tmux ttyd git && \
    git clone -b $VERSION https://github.com/sirrobot01/decypharr.git  /source

# Stage 1: Build binaries
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG VERSION=0.0.0
ARG CHANNEL=dev

WORKDIR /app

COPY --from=cloner /source/go.mod /source/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

COPY --from=cloner /source/. .

# Build main binary
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath \
    -ldflags="-w -s -X github.com/sirrobot01/decypharr/pkg/version.Version=${VERSION} -X github.com/sirrobot01/decypharr/pkg/version.Channel=${CHANNEL}" \
    -o /decypharr

# Build healthcheck (optimized)
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-w -s" \
    -o /healthcheck cmd/healthcheck/main.go

# Stage 2: Create directory structure
FROM alpine:3.21 as dirsetup
RUN mkdir -p /app/logs && \
    mkdir -p /app/cache && \
    chmod 777 /app/logs && \
    touch /app/logs/decypharr.log && \
    chmod 666 /app/logs/decypharr.log

# Stage 3: Final image
FROM ghcr.io/ipromknight/alpine:rolling

LABEL version = "${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source = "https://github.com/sirrobot01/decypharr"
LABEL org.opencontainers.image.title = "decypharr"
LABEL org.opencontainers.image.authors = "sirrobot01"
LABEL org.opencontainers.image.documentation = "https://github.com/sirrobot01/decypharr/blob/main/README.md"

# Copy binaries
COPY --from=builder --chown=568:568 /decypharr /usr/bin/decypharr
COPY --from=builder --chown=568:568 /healthcheck /usr/bin/healthcheck

# Copy pre-made directory structure
COPY --from=dirsetup --chown=568:568 /app /app

# Metadata
ENV LOG_PATH=/config/logs
EXPOSE 8282

USER 568

# So that the app will start for goss tests
COPY --chown=568:568 apps/decypharr/config.json /config/

COPY --chmod=0755 apps/decypharr/promknight-entrypoint.sh /promknight-entrypoint.sh
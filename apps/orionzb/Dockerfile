FROM alpine AS cloner
ARG VERSION
RUN apk add --update --no-cache git && \
    git clone -b $VERSION https://github.com/iPromKnight/orionzb.git /source

# Pure Go (no CGO) — pinned to BUILDPLATFORM so Go runs natively, cross via GOOS/GOARCH
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG VERSION=0.0.0
ARG CHANNEL=dev

WORKDIR /app

COPY --from=cloner /source/go.mod /source/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

COPY --from=cloner /source/. .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-w -s" \
    -o /orionzb ./cmd/orionzb

# Final image — same base family as decypharr/altmount
FROM ghcr.io/ipromknight/alpine:rolling

ARG VERSION=0.0.0
ARG CHANNEL=dev

LABEL version="${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source="https://github.com/iPromKnight/orionzb"
LABEL org.opencontainers.image.title="orionzb"
LABEL org.opencontainers.image.authors="iPromKnight"
LABEL org.opencontainers.image.documentation="https://github.com/iPromKnight/orionzb/blob/main/README.md"

WORKDIR /app

COPY --from=builder --chown=568:568 /orionzb /usr/bin/orionzb

# Bake the config symlink at build time so 568 doesn't need to write to /app.
# orionzb's config.Load() reads ./config.json from CWD if present.
RUN ln -sfn /config/config.json /app/config.json && \
    install -d -o 568 -g 568 /config

EXPOSE 3000

USER 568

COPY --chown=568:568 apps/orionzb/config.json /config/config.json

COPY --chmod=0755 apps/orionzb/promknight-entrypoint.sh /promknight-entrypoint.sh

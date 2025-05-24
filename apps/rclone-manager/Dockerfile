FROM alpine:latest AS cloner

ARG VERSION

RUN apk update && apk upgrade && \
    apk add --no-cache git

RUN git clone -b main https://github.com/iPromKnight/rclone-manager /source

FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache git

WORKDIR /app

COPY --from=cloner /source/src/go.mod /source/src/go.sum .

RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

COPY --from=cloner /source/src/. .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath \
    -ldflags="-w -s" \
    -o /rclone-manager \
    cmd/main.go

FROM ghcr.io/ipromknight/alpine:rolling

ARG VERSION

RUN apk add --no-cache \
    fuse3 \
    curl \
    su-exec \
    unzip 

ARG TARGETARCH=amd64
ENV ARCH_SUFFIX=${TARGETARCH}

RUN \
  case "${TARGETPLATFORM}" in \
      'linux/amd64') export ARCH='amd64' ;; \
      'linux/arm64') export ARCH='arm64' ;; \
      *) echo "Unsupported TARGETPLATFORM: ${TARGETPLATFORM}" && exit 1 ;; \
  esac \
  && curl -fsSL "https://github.com/rclone/rclone/releases/download/v${VERSION}/rclone-v${VERSION}-linux-${ARCH}.zip" -o /tmp/rclone.zip \
  && unzip /tmp/rclone.zip "rclone-v${VERSION}-linux-${ARCH}/rclone" -d /tmp \
  && install -m 0755 /tmp/rclone-v${VERSION}-linux-${ARCH}/rclone /usr/local/bin/rclone \
  && rm -rf /tmp/rclone*

RUN mkdir -p /data

RUN ln -s /usr/bin/fusermount3 /usr/bin/fusermount

COPY --from=builder --chmod=0755 /rclone-manager /usr/local/bin/rclone-manager

RUN echo "user_allow_other" >> /etc/fuse.conf

COPY --chmod=0755 ./apps/rclone-manager/promknight-entrypoint.sh /promknight-entrypoint.sh


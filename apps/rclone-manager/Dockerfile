FROM alpine:latest AS cloner

ARG VERSION

RUN apk update && apk upgrade && \
    apk add --no-cache git

RUN git clone -b main https://github.com/iPromKnight/rclone-manager /source

FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app

COPY --from=cloner /source/src/go.mod go.sum* ./
RUN go mod download

COPY --from=cloner /source/src/ ./
RUN go build -o rclone-manager ./cmd/main.go

FROM ghcr.io/ipromknight/alpine:rolling

ARG VERSION

RUN apk add --no-cache \
    fuse3 \
    curl \
    su-exec \
    unzip

RUN curl -Lso /tmp/rclone.zip "https://github.com/rclone/rclone/releases/download/v${VERSION}/rclone-v${VERSION}-linux-amd64.zip" && \
    unzip /tmp/rclone.zip "rclone-v${VERSION}-linux-amd64/rclone" -d /tmp && \
    install -m 0755 /tmp/rclone-v${VERSION}-linux-amd64/rclone /usr/local/bin/rclone && \
    rm -rf /tmp/rclone*

RUN mkdir -p /data

RUN ln -s /usr/bin/fusermount3 /usr/bin/fusermount

COPY --from=builder --chmod=0755 /app/rclone-manager /usr/local/bin/rclone-manager

RUN echo "user_allow_other" >> /etc/fuse.conf

COPY --chmod=0755 ./apps/rclone-manager/promknight-entrypoint.sh /promknight-entrypoint.sh


FROM alpine:latest AS cloner

ARG VERSION

RUN apk update && apk upgrade && \
    apk add --no-cache git

RUN git clone -b $VERSION https://github.com/iPromKnight/rclone-manager /source

FROM --platform=linux/amd64 golang:1.24-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app

COPY --from=cloner /source/src/go.mod go.sum* ./
RUN go mod download

COPY --from=cloner /source/src/ ./
RUN go build -o rclone-manager ./cmd/main.go

FROM ghcr.io/ipromknight/alpine:rolling

RUN apk add --no-cache \
    fuse3 \
    curl \
    rclone \
    su-exec

RUN mkdir -p /data

RUN ln -s /usr/bin/fusermount3 /usr/bin/fusermount

COPY --from=builder --chmod=0755 /app/rclone-manager /usr/local/bin/rclone-manager

RUN echo "user_allow_other" >> /etc/fuse.conf

COPY --chmod=0755 ./apps/rclone-manager/promknight-entrypoint.sh /promknight-entrypoint.sh


FROM alpine:latest AS cloner

ARG VERSION

RUN apk update && apk upgrade && \
    apk add --no-cache git

RUN git clone -b $VERSION https://github.com/thrnz/docker-wireguard-pia.git /source

FROM --platform=$BUILDPLATFORM golang:1.24.3-alpine AS wireguard-builder

ARG TARGETOS
ARG TARGETARCH
ARG WIREGUARD_TAG=0.0.20250522
ENV WIREGUARD_TAG=${WIREGUARD_TAG}

RUN apk add --no-cache wget unzip make git

WORKDIR /src

# Download and extract
RUN wget https://github.com/WireGuard/wireguard-go/archive/refs/tags/${WIREGUARD_TAG}.zip -O wg.zip && \
    unzip wg.zip && \
    mv wireguard-go-${WIREGUARD_TAG} wireguard-go

WORKDIR /src/wireguard-go

# Inject version.go to avoid git describe issues
RUN printf 'package main\n\nconst Version = "%s"\n' "${WIREGUARD_TAG}" > version.go

# Build binary
RUN make wireguard-go

FROM ghcr.io/ipromknight/alpine:rolling

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    grepcidr3 \
    iptables \
    iptables-legacy \
    libcap-utils \
    jq \
    openssl \
    wireguard-tools

# Modify wg-quick so it doesn't die without --privileged
# Set net.ipv4.conf.all.src_valid_mark=1 on container creation using --sysctl if required instead
# To avoid confusion, also suppress the error message that displays even when pre-set to 1 on container creation
RUN sed -i 's/cmd sysctl.*/set +e \&\& sysctl -q net.ipv4.conf.all.src_valid_mark=1 \&> \/dev\/null \&\& set -e/' /usr/bin/wg-quick

# Get the PIA CA cert
ADD https://raw.githubusercontent.com/pia-foss/desktop/master/daemon/res/ca/rsa_4096.crt /rsa_4096.crt

# The PIA desktop app uses this public key to verify server list downloads
# https://github.com/pia-foss/desktop/blob/master/daemon/src/environment.cpp#L30

# Add main work dir to PATH
WORKDIR /scripts

COPY --from=cloner /source/RegionsListPubKey.pem /RegionsListPubKey.pem
COPY --from=cloner /source/run /scripts/
COPY --from=cloner /source/healthcheck.sh /scripts/
COPY --from=cloner /source/pf_success.sh /scripts/
COPY --from=cloner /source/extra/pf.sh /scripts/
COPY --from=cloner /source/extra/pia-auth.sh /scripts/
COPY --from=cloner /source/extra/wg-gen.sh /scripts/
COPY --from=wireguard-builder --chmod=0755 /src/wireguard-go/wireguard-go /usr/local/bin/wireguard-go
RUN chmod 755 /scripts/*

# Store persistent PIA stuff here (auth token, server list)
VOLUME /pia

# Store stuff that might be shared with another container here (eg forwarded port)
VOLUME /pia-shared

ARG BUILDINFO=manual
ENV BUILDINFO=${BUILDINFO}


COPY --chmod=0755 ./apps/pia/promknight-entrypoint.sh /promknight-entrypoint.sh
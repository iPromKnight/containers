FROM alpine AS cloner

ARG VERSION
ARG TARGETARCH

RUN mkdir -p /app /config && \
    apk add --update --no-cache wget && \
    case "$TARGETARCH" in \
        amd64) ARCH="x86_64-unknown-linux-musl" ;; \
        arm64) ARCH="aarch64-unknown-linux-musl" ;; \
        *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac && \
    wget -O /app/tuliprox "https://github.com/euzu/tuliprox/releases/download/v${VERSION}/tuliprox-v${VERSION}-${ARCH}" && \
    chmod +x /app/tuliprox && \
    wget -O /tmp/web.tar.gz "https://github.com/euzu/tuliprox/releases/download/v${VERSION}/web_resources_release_v${VERSION}.tar.gz" && \
    tar -xzf /tmp/web.tar.gz -C /app --strip-components=2 && \
    rm -rf /tmp/web.tar.gz && \
    touch /config/user.txt

FROM ghcr.io/ipromknight/ubuntu:rolling

ARG VERSION

LABEL org.opencontainers.image.title="tuliprox"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.source="euzu/tuliprox"

# ffmpeg/ffprobe needed at runtime for tuliprox's probe feature
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV TULIPROX_HOME="/app"

COPY --from=cloner /app /app
COPY --from=cloner /config /config

COPY --chmod=0755 ./apps/tuliprox/promknight-entrypoint.sh /promknight-entrypoint.sh
USER 568
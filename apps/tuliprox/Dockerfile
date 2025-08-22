FROM alpine AS cloner

ARG VERSION

RUN mkdir -p /app /config && \
    apk add --update --no-cache wget && \
    wget -O /tmp/tuliprox.tgz https://github.com/euzu/tuliprox/releases/download/v${VERSION}/tuliprox_v${VERSION}_linux_x86_64.tgz && \
    tar -xzf /tmp/tuliprox.tgz -C /app --strip-components=1 && \
    chmod +x /app/tuliprox && \
    mkdir -p /app/resources && \
    mv /app/*.ts /app/resources/ && \
    mv /app/*.yml /config && \
    touch /config/user.txt && \
    rm -rf /tmp/tuliprox*

FROM ghcr.io/ipromknight/ubuntu:rolling

LABEL org.opencontainers.image.title="tuliprox"

WORKDIR /app
ENV TULIPROX_HOME="/app"
COPY --from=cloner /app .
COPY --from=cloner /config /config
COPY --chmod=0755 ./apps/tuliprox/promknight-entrypoint.sh /promknight-entrypoint.sh
USER 568

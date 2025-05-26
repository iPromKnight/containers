FROM alpine:3.21 AS cloner

RUN apk add --no-cache \
    curl unzip

ARG VERSION

RUN set -eux; \
    arch="$(apk --print-arch)"; \
    case "$arch" in \
    'x86_64') arch_suffix="amd64" ;; \
    'aarch64') arch_suffix="arm64" ;; \
    *) \
      echo >&2 "error: unsupported architecture '$arch'."; \
      exit 1 \
      ;; \
    esac; \
    RELEASE_URL="https://api.github.com/repos/Pryaxis/TShock/releases/tags/$VERSION"; \
    TSHOCKURL=$(curl -s $RELEASE_URL | grep browser_download_url | grep "linux-$arch_suffix-Release.zip" | cut -d '"' -f 4); \
    TSHOCKZIP=$(basename $TSHOCKURL); \
    curl -L -o "/$TSHOCKZIP" "$TSHOCKURL"; \
    unzip "$TSHOCKZIP" -d "/tshock"; \
    tar -xvf "/tshock/"*.tar -C "/tshock"; \
    rm "$TSHOCKZIP"; \
    chmod +x "/tshock/TShock.Server"

FROM mcr.microsoft.com/dotnet/runtime:6.0

COPY --from=cloner /tshock /tshock

RUN set -eux; \
    mkdir -p /tshock/ServerPlugins; \
    mkdir -p /tshock/logs; \
    mkdir -p /config; \
    mkdir -p /plugins; \
    ln -s /tshock/TShock.Server /usr/local/bin/tshock

ENV CONFIGPATH=/config
ENV LOGPATH=/tshock/logs
ENV WORLD_FILENAME=""

VOLUME ["/config", "/tshock/logs", "/tshock/ServerPlugins"]

EXPOSE 7777 7878


RUN apt-get update -y && \
    apt-get install -y nuget jq tmux && \
    rm -rf /var/lib/apt/lists/* /tmp/*

ADD --chmod=0755 https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 /usr/local/bin/ttyd 

COPY --chmod=0755 ./apps/tshock/root /

ENTRYPOINT ["/promknight-entrypoint.sh"]
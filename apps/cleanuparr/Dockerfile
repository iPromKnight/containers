FROM alpine AS cloner

ARG VERSION
ARG DOTNET_VERSION="9.0.8"

RUN mkdir -p /app && \
    apk add --update --no-cache wget && \
    wget -O /tmp/cleanuparr.zip https://github.com/Cleanuparr/Cleanuparr/releases/download/v${VERSION}/Cleanuparr-${VERSION}-linux-amd64.zip && \
    unzip -o /tmp/cleanuparr.zip -d /app && \
    mv /app/*/* /app/ 2>/dev/null || true && \
    chmod +x /app/Cleanuparr && \
    rm -rf /tmp/cleanuparr*

FROM ghcr.io/ipromknight/ubuntu:rolling

ARG DOTNET_VERSION="9.0.8"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gosu \
        \
        libc6 \
        libgcc-s1 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN dotnet_archive=dotnet-runtime-${DOTNET_VERSION}-linux-x64.tar.gz \
    \
    && curl --fail --show-error --location \
        --remote-name https://builds.dotnet.microsoft.com/dotnet/Runtime/${DOTNET_VERSION}/${dotnet_archive} \
    && mkdir -p /usr/share/dotnet \
    && tar --gzip --extract --no-same-owner --file ${dotnet_archive} --directory /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    && rm \
        ${dotnet_archive}

LABEL org.opencontainers.image.title="Cleanuparr"

WORKDIR /app
COPY --from=cloner --chown=568:568 /app .
COPY --chmod=0755 ./apps/cleanuparr/promknight-entrypoint.sh /promknight-entrypoint.sh
ENV PUID=568 \
    PGID=568 \
    UMASK=022 \
    TZ=Etc/UTC \
    HTTP_PORTS=11011 \
    DOTNET_USE_POLLING_FILE_WATCHER=true


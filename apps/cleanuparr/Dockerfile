FROM alpine AS cloner

ARG VERSION
ARG DOTNET_VERSION="9.0.8"

RUN apk add --update --no-cache git

RUN mkdir -p /src || exit 1 \
    && git clone --depth 1 --branch v${VERSION} https://github.com/Cleanuparr/Cleanuparr.git /src

# Build Angular frontend
FROM --platform=$BUILDPLATFORM node:18-alpine AS frontend-build
WORKDIR /app
COPY --from=cloner /src/code/frontend/package*.json ./
RUN npm ci && npm install -g @angular/cli
COPY --from=cloner /src/code/frontend/ .
RUN npm run build

# Build .NET backend
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0-bookworm-slim AS build
ARG TARGETARCH
ARG VERSION=0.0.1
ARG PACKAGES_USERNAME=ipromknight
WORKDIR /app
COPY --from=cloner /src/code/backend/ ./backend/

RUN --mount=type=secret,id=PUBLIC_PACKAGES_TOKEN,env=PUBLIC_PACKAGES_TOKEN \
    dotnet nuget add source \
      --name Cleanuparr \
      --username "${PACKAGES_USERNAME}" \
      --password "${PUBLIC_PACKAGES_TOKEN}" \
      --store-password-in-clear-text \
      https://nuget.pkg.github.com/Cleanuparr/index.json \
 && dotnet restore -a $TARGETARCH ./backend/Cleanuparr.Api/Cleanuparr.Api.csproj \
 && dotnet nuget remove source Cleanuparr \
 && rm -f /root/.nuget/NuGet/NuGet.Config
    
RUN dotnet publish ./backend/Cleanuparr.Api/Cleanuparr.Api.csproj \
    -a $TARGETARCH \
    -c Release \
    -o /app/publish \
    --no-restore \
    /p:Version=${VERSION} \
    /p:PublishSingleFile=true \
    /p:DebugSymbols=false

# Final stage
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
COPY --from=build --chown=568:568 /app/publish .
COPY --from=frontend-build --chown=568:568 /app/dist/ui/browser ./wwwroot
COPY --chmod=0755 ./apps/cleanuparr/promknight-entrypoint.sh /promknight-entrypoint.sh
ENV PUID=568 \
    PGID=568 \
    UMASK=022 \
    TZ=Etc/UTC \
    HTTP_PORTS=11011 \
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    SEED_USER=true
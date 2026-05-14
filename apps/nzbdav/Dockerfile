FROM alpine AS cloner
ARG VERSION
RUN apk add --update --no-cache git && \
    git clone -b $VERSION https://github.com/nzbdav-dev/nzbdav.git /source

# Frontend build — node, BUILDPLATFORM (frontend is platform-agnostic JS)
FROM --platform=$BUILDPLATFORM node:alpine AS frontend-build
WORKDIR /frontend
COPY --from=cloner /source/frontend/. .
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm install && \
    npm run build && \
    npm run build:server && \
    npm prune --omit=dev

# Backend build — .NET SDK on BUILDPLATFORM, cross-publishes to TARGETARCH
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS backend-build
ARG TARGETARCH
WORKDIR /backend
COPY --from=cloner /source/backend/. .
RUN --mount=type=cache,target=/root/.nuget/packages,sharing=locked \
    dotnet restore && \
    dotnet publish -c Release -r linux-musl-${TARGETARCH} -o ./publish

# Final image — same custom alpine base used by every other promknight container
FROM ghcr.io/ipromknight/alpine:rolling

ARG VERSION=0.0.0
ARG CHANNEL=dev
ARG TARGETARCH

LABEL version="${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source="https://github.com/nzbdav-dev/nzbdav"
LABEL org.opencontainers.image.title="nzbdav"
LABEL org.opencontainers.image.authors="nzbdav-dev"
LABEL org.opencontainers.image.documentation="https://github.com/nzbdav-dev/nzbdav/blob/main/README.md"

# Runtime deps:
# - icu-libs + libstdc++: required by .NET on alpine (globalisation + native runtime)
# - nodejs/npm: SSR frontend is run with `npm run start`
# - su-exec: drop from root → 568 in the entrypoint after wait-for-* helpers
RUN apk add --no-cache \
        icu-libs \
        libstdc++ \
        nodejs \
        npm \
        su-exec

# Install ASP.NET Core 10 runtime via Microsoft's official install script.
# Pinned channel = 10.0; install dir = /usr/share/dotnet (FHS-friendly).
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH=$PATH:/usr/share/dotnet
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh \
        --channel 10.0 \
        --runtime aspnetcore \
        --install-dir "$DOTNET_ROOT" \
        --no-path && \
    rm /tmp/dotnet-install.sh && \
    dotnet --info

WORKDIR /app

# Frontend
COPY --from=frontend-build --chown=568:568 /frontend/node_modules ./frontend/node_modules
COPY --from=frontend-build --chown=568:568 /frontend/package.json  ./frontend/package.json
COPY --from=frontend-build --chown=568:568 /frontend/dist-node/server.js ./frontend/dist-node/server.js
COPY --from=frontend-build --chown=568:568 /frontend/build ./frontend/build

# Backend
COPY --from=backend-build  --chown=568:568 /backend/publish ./backend

# nzbdav stores all settings + db.sqlite under CONFIG_PATH; mount /config to persist.
ENV NZBDAV_VERSION=${VERSION}
ENV NODE_ENV=production
ENV LOG_LEVEL=warning
ENV CONFIG_PATH=/config
# Backend listens on :8080 internally; the SSR frontend on :3000 proxies to it.
# Kestrel needs ASPNETCORE_URLS to bind anywhere other than the default :5000.
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENV BACKEND_URL=http://localhost:8080

EXPOSE 3000

COPY --chmod=0755 apps/nzbdav/promknight-entrypoint.sh /promknight-entrypoint.sh

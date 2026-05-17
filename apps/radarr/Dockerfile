FROM ghcr.io/ipromknight/alpine:rolling

ARG TARGETPLATFORM
ARG VERSION
ARG CHANNEL

ENV \
    RADARR__INSTANCE_NAME="Radarr" \
    RADARR__BRANCH="${CHANNEL}" \
    RADARR__PORT="7878" \
    RADARR__ANALYTICS_ENABLED="False"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# for initial install
USER root

#hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates icu-libs libintl sqlite-libs xmlstarlet postgresql-client pgloader sqlite
#hadolint ignore=DL3059
RUN \
    case "${TARGETPLATFORM}" in \
        'linux/amd64') export ARCH='x64' ;; \
        'linux/arm64') export ARCH='arm64' ;; \
    esac \
    && \
    mkdir -p /app/bin \
    && \
    ASSET_URL=$(curl -fsSL "https://api.github.com/repos/realzombee/Radarr/releases/tags/v${VERSION}" \
        | jq -r --arg suffix "linux-musl-core-${ARCH}.tar.gz" \
            '.assets[] | select(.name | endswith($suffix)) | .browser_download_url') \
    && \
    [ -n "${ASSET_URL}" ] || { echo "No matching asset for v${VERSION} ${ARCH}"; exit 1; } \
    && \
    curl -fsSL "${ASSET_URL}" \
        | tar xzf - -C /app/bin --strip-components=1 \
    && \
    rm -rf \
        /app/bin/Radarr.Update \
    && \
    printf "UpdateMethod=docker\nBranch=%s\nPackageVersion=%s\nPackageAuthor=[realzombee](https://github.com/realzombee)\n" "${RADARR__BRANCH}" "${VERSION}" > /app/package_info \
    && chown -R root:root /app \
    && chmod -R 755 /app \
    && rm -rf /tmp/*

RUN mv /app/bin/ffprobe /app/bin/ffprobe-real
COPY --chmod=0755 ./apps/radarr/ffprobe /app/bin/ffprobe

USER 568

ENV COMPlus_EnableDiagnostics=0
ENV REAL_FFPROBE_PATH=/app/bin/ffprobe-real

COPY ./apps/radarr/config.xml.tmpl /app/config.xml.tmpl
COPY --chmod=0755 ./apps/radarr/promknight-entrypoint.sh /promknight-entrypoint.sh

LABEL org.opencontainers.image.source="https://github.com/realzombee/Radarr"
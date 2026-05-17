FROM ghcr.io/ipromknight/alpine:rolling

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG VERSION
ARG CHANNEL

ENV \
    SONARR__INSTANCE_NAME="Sonarr" \
    SONARR__BRANCH="${CHANNEL}" \
    SONARR__PORT="8989" \
    SONARR__ANALYTICS_ENABLED="False"

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
    ASSET_URL=$(curl -fsSL "https://api.github.com/repos/realzombee/Sonarr/releases/tags/v${VERSION}" \
        | jq -r --arg suffix "linux-musl-${ARCH}.tar.gz" \
            '.assets[] | select(.name | endswith($suffix)) | .browser_download_url') \
    && \
    [ -n "${ASSET_URL}" ] || { echo "No matching asset for v${VERSION} ${ARCH}"; exit 1; } \
    && \
    curl -fsSL "${ASSET_URL}" \
        | tar xzf - -C /app --strip-components=1 \
    && \
    rm -rf \
        /app/Sonarr.Update \
    && \
    printf "UpdateMethod=docker\nBranch=%s\nPackageVersion=%s\nPackageAuthor=[realzombee](https://github.com/realzombee)" "${SONARR__BRANCH}" "${VERSION}" > /app/package_info \
    && chown -R root:root /app \
    && chmod -R 755 /app \
    && rm -rf /tmp/*

RUN  mv /app/ffprobe /app/ffprobe-real
COPY --chmod=0755 ./apps/sonarr/ffprobe /app/ffprobe

USER 568
ENV REAL_FFPROBE_PATH=/app/ffprobe-real

COPY ./apps/sonarr/config.xml.tmpl /app/config.xml.tmpl
COPY --chmod=0755 ./apps/sonarr/promknight-entrypoint.sh /promknight-entrypoint.sh

LABEL org.opencontainers.image.title="${SONARR__INSTANCE_NAME} (${SONARR__BRANCH})"
LABEL org.opencontainers.image.source="https://github.com/realzombee/Sonarr"

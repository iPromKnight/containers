FROM ghcr.io/ipromknight/alpine:rolling

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG VERSION
ARG CHANNEL

ENV \
    PROWLARR__INSTANCE_NAME="Prowlarr" \
    PROWLARR__BRANCH="${CHANNEL}" \
    PROWLARR__PORT="9696" \
    PROWLARR__ANALYTICS_ENABLED="False"

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
    ASSET_URL=$(curl -fsSL "https://api.github.com/repos/realzombee/Prowlarr/releases/tags/v${VERSION}" \
        | jq -r --arg suffix "linux-musl-core-${ARCH}.tar.gz" \
            '.assets[] | select(.name | endswith($suffix)) | .browser_download_url') \
    && \
    [ -n "${ASSET_URL}" ] || { echo "No matching asset for v${VERSION} ${ARCH}"; exit 1; } \
    && \
    curl -fsSL "${ASSET_URL}" \
        | tar xzf - -C /app --strip-components=1 \
    && \
    rm -rf \
        /app/Prowlarr.Update \
    && \
    printf "UpdateMethod=docker\nBranch=%s\nPackageVersion=%s\nPackageAuthor=[realzombee](https://github.com/realzombee)" "${PROWLARR__BRANCH}" "${VERSION}" > /app/package_info \
    && chown -R root:root /app \
    && chmod -R 755 /app \
    && rm -rf /tmp/*

ENV COMPlus_EnableDiagnostics=0

USER 568
COPY ./apps/prowlarr/config.xml.tmpl /app/config.xml.tmpl
COPY --chmod=0755 ./apps/prowlarr/promknight-entrypoint.sh /promknight-entrypoint.sh

LABEL org.opencontainers.image.source="https://github.com/realzombee/Prowlarr"

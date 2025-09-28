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
    curl -fsSL "https://radarr.servarr.com/v1/update/${RADARR__BRANCH}/updatefile?version=${VERSION}&os=linuxmusl&runtime=netcore&arch=${ARCH}" \
        | tar xzf - -C /app/bin --strip-components=1 \
    && \
    rm -rf \
        /app/bin/Radarr.Update \
    && \
    printf "UpdateMethod=docker\nBranch=%s\nPackageVersion=%s\nPackageAuthor=[ipromknight](https://github.com/ipromknight)\n" "${RADARR__BRANCH}" "${VERSION}" > /app/package_info \
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

LABEL org.opencontainers.image.source="https://github.com/Radarr/Radarr"
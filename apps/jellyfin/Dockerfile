FROM ghcr.io/ipromknight/ubuntu:rolling@sha256:7023b1419420f9cdb10f46c837fd80bf2b615f6aa273fdd82c45105b216fbdf1

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG VERSION
ARG CHANNEL

ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

# Disable glibc dynamic heap adjustment
ENV MALLOC_TRIM_THRESHOLD_=131072

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Replace malloc with jemalloc
RUN apt-get -qq update \
    && apt-get -qq install -y libjemalloc2 libjemalloc-dev 

RUN curl -sL https://repositories.intel.com/graphics/intel-graphics.key | apt-key add - \
        && echo 'deb [arch=amd64] https://repositories.intel.com/graphics/ubuntu focal main' > /etc/apt/sources.list.d/intel.list \
        && \
        export ARCH='amd64'; \
        export EXTRA_INSTALL_ARG='intel-media-va-driver-non-free nvidia-opencl-icd-340 i965-va-driver mesa-va-drivers'

RUN \
    apt-get -qq update \
    && \
    apt-get -qq install -y \
        gnupg2 \
    && \
    apt-get -qq update \
    && \
    apt-get -qq install -y \
        ca-certificates \
        ${EXTRA_INSTALL_ARG} \
    && \
    curl -fsSL "https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key" | apt-key add - && \
    echo "deb [arch=amd64] https://repo.jellyfin.org/ubuntu focal main" | tee /etc/apt/sources.list.d/jellyfin.list && \
    apt-get -qq update && \
    apt-get -qq install -y \
        jellyfin-server="${VERSION}*" \
        jellyfin-web \
        jellyfin-ffmpeg5 \
    && \
    apt-get remove -y gnupg2 \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && apt-get autoremove -y \
    && apt-get clean \
    && \
    rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/ \
    && printf "umask %d" "${UMASK}" >> /etc/bash.bashrc 

ENV LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"

USER 568

COPY --chmod=0755 ./apps/jellyfin/promknight-entrypoint.sh /promknight-entrypoint.sh

LABEL org.opencontainers.image.source="https://github.com/jellyfin/jellyfin"

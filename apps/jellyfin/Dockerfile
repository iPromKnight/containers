FROM mcr.microsoft.com/dotnet/sdk:8.0 AS deovr-plugin-builder

RUN apt-get update && \
    apt-get install -y \
    wget \
    curl \
    unzip \
    jq \
    && rm -rf /var/lib/apt/lists/*
    
RUN set -ex && \
    version=$(curl -s https://api.github.com/repos/iPromKnight/DeoVRDeeplink/releases/latest | jq -r .tag_name) && \
    version="${version#v}" && \
    wget -q "https://github.com/iPromKnight/DeoVRDeeplink/archive/refs/tags/v${version}.zip" -O /tmp/plugin.zip && \
    unzip -q /tmp/plugin.zip -d /tmp && \
    mkdir -p /src /artifacts && \
    cp -r /tmp/DeoVRDeeplink-${version}/* /src/

RUN dotnet build --configuration Release --output /artifacts /src/DeoVRDeeplink/DeoVRDeeplink.csproj

# Stage 2: Final image
FROM jellyfin/jellyfin:latest
COPY --from=builder /src/bin/Release/net7.0/DeoVRDeeplink.dll /opt/plugins/DeoVRDeeplink/DeoVRDeeplink.dll

FROM ghcr.io/ipromknight/ubuntu:rolling

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG VERSION
ARG CHANNEL

ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

# Disable glibc dynamic heap adjustment
ENV MALLOC_TRIM_THRESHOLD_=131072

# Disable file locking in .NET Core
ENV DOTNET_SYSTEM_IO_DISABLEFILELOCKING="true"

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


COPY --from=deovr-plugin-builder /artifacts/DeoVRDeeplink.dll /opt/plugins/DeoVRDeeplink/DeoVRDeeplink.dll

COPY --chmod=0755 ./apps/jellyfin/promknight-entrypoint.sh /promknight-entrypoint.sh

LABEL org.opencontainers.image.source="https://github.com/jellyfin/jellyfin"

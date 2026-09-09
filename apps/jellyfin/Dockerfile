FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:11.0 AS deovr-plugin-builder

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

ARG TARGETARCH

RUN \
    apt-get -qq update \
    && apt-get -qq install -y ca-certificates gnupg \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg \
    && echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu noble main" \
        > /etc/apt/sources.list.d/jellyfin.list \
    && case "${TARGETARCH}" in \
        amd64) \
            curl -fsSL https://repositories.intel.com/gpu/intel-graphics.key \
                | gpg --dearmor -o /etc/apt/keyrings/intel-graphics.gpg \
            && echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble unified' \
                > /etc/apt/sources.list.d/intel.list \
            && EXTRA_GPU_PKGS='intel-media-va-driver-non-free i965-va-driver mesa-va-drivers' \
            && JEMALLOC_TRIPLE='x86_64-linux-gnu' \
            ;; \
        arm64) \
            EXTRA_GPU_PKGS='mesa-va-drivers' \
            && JEMALLOC_TRIPLE='aarch64-linux-gnu' \
            ;; \
        *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && apt-get -qq update \
    && apt-get -qq install -y \
        ${EXTRA_GPU_PKGS} \
        jellyfin-server="${VERSION}*" \
        jellyfin-web \
        jellyfin-ffmpeg7 \
    && ln -sf "/usr/lib/${JEMALLOC_TRIPLE}/libjemalloc.so.2" /usr/local/lib/libjemalloc.so.2 \
    && apt-get remove -y gnupg \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/ \
    && printf "umask %d" "${UMASK}" >> /etc/bash.bashrc

ENV LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"

USER 568


COPY --from=deovr-plugin-builder /artifacts/DeoVRDeeplink.dll /opt/plugins/DeoVRDeeplink/DeoVRDeeplink.dll

COPY --chmod=0755 ./apps/jellyfin/promknight-entrypoint.sh /promknight-entrypoint.sh

LABEL org.opencontainers.image.source="https://github.com/jellyfin/jellyfin"

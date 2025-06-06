ARG VERSION
FROM public.ecr.aws/docker/library/golang:1.22.3-alpine3.18 AS builder
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT=""
ARG TARGETPLATFORM
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    GOARM=${TARGETVARIANT}
RUN go install -ldflags="-s -w" github.com/drone/envsubst/cmd/envsubst@latest

# TODO: upx for arm64 not in alpine 3.16
#hadolint ignore=DL3018,DL3059
RUN \
    case "${TARGETPLATFORM}" in \
        'linux/amd64') \
            # 1.9M -> 1.0M
            apk add --no-cache upx \
            && upx --ultra-brute /go/bin/envsubst \
        ;; \
    esac

FROM public.ecr.aws/docker/library/alpine:${VERSION}
ARG VERSION
ARG CHANNEL
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

ENV UMASK="0002" \
    TZ="Etc/UTC"

WORKDIR /app

#hadolint ignore=DL3018
RUN \
    apk add --no-cache \
        # 656 kB           # 1.28 MB     # 632 kB
        ca-certificates    bash          bind-tools \
        # 256 kB           # 156 kB      # 40 kB
        curl               iputils       jo \
        # 564 kB           # 200 kB      # 316 kB
        jq                 moreutils     nano \
        # 76 kB
        pv \
        # 36 kB            # 3.3 MB      # 320 kB
        tini               tzdata        unzip \
        # 16 kB            # 480 kB
        util-linux         wget          dumb-init \
    && \
    # 264 kB
    apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.14/main unrar

#hadolint ignore=DL3018
RUN \
    addgroup -S notroot --gid 568 \
        && adduser -S notroot -G notroot --uid 568 \
    && \
    mkdir -p /config \
    && chown -R notroot:notroot /config \
    && chmod -R 775 /config \
    && printf "/bin/bash /scripts/greeting.sh\n" > /etc/profile.d/greeting.sh \
    && printf "umask %d" "${UMASK}" > /etc/profile.d/umask.sh \
    && ln -s /usr/bin/vi   /usr/local/bin/vi \
    && ln -s /usr/bin/vi   /usr/local/bin/vim \
    && ln -s /usr/bin/nano /usr/local/bin/nano \
    && ln -s /usr/bin/nano /usr/local/bin/neovim \
    && ln -s /usr/bin/nano /usr/local/bin/emacs \
    && rm -rf /tmp/*

VOLUME ["/config"]
RUN mkdir -p /extra_scripts \
    && chown -R notroot:notroot /extra_scripts \
    && chmod -R 775 /extra_scripts
COPY ./apps/alpine/scripts /prom_scripts
COPY --chmod=0755 apps/alpine/base-entrypoint.sh /base-entrypoint.sh
COPY --chmod=0755 apps/alpine/promknight-entrypoint.sh /promknight-entrypoint.sh
COPY --from=builder /go/bin/envsubst /usr/local/bin/envsubst
ENTRYPOINT ["/base-entrypoint.sh"]

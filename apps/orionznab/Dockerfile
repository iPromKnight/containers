FROM alpine AS cloner

ARG VERSION
ARG TARGETARCH

RUN apk add --update --no-cache wget && \
    case "$TARGETARCH" in \
        *amd64 | */amd64/*) PLATFORM=x86_64 ;; \
        *arm64 | */arm64/* ) PLATFORM=aarch64 ;; \
        * ) echo "Unexpected TARGETARCH '$TARGETARCH'" >&2; exit 1 ;; \
    esac && \
    wget -O /tmp/orionznab.tar.gz https://github.com/iPromKnight/orionznab/releases/download/v$VERSION/orionznab-${PLATFORM}-unknown-linux-musl.tar.gz && \
    tar -xzf /tmp/orionznab.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/orionznab && \
    rm -rf /tmp/orionznab*

FROM --platform=$TARGETARCH gcr.io/distroless/static-debian12:latest

LABEL org.opencontainers.image.source = "https://github.com/ipromknight/orionznab"
LABEL org.opencontainers.image.title = "orionznab"
LABEL org.opencontainers.image.authors = "ipromknight"
LABEL org.opencontainers.image.documentation = "https://github.com/ipromknight/orionznab/blob/main/README.md"

COPY --from=cloner /usr/local/bin/orionznab /usr/bin/orionznab

ENTRYPOINT ["/usr/bin/orionznab"]
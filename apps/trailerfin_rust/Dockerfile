FROM alpine AS cloner

ARG VERSION
ARG TARGETARCH

RUN apk add --update --no-cache wget && \
    case "$TARGETARCH" in \
        *amd64 | */amd64/*) PLATFORM=x86_64 ;; \
        *arm64 | */arm64/* ) PLATFORM=aarch64 ;; \
        * ) echo "Unexpected TARGETARCH '$TARGETARCH'" >&2; exit 1 ;; \
    esac && \
    wget -O /tmp/trailerfin_rust.tar.gz https://github.com/iPromKnight/trailerfin_rust/releases/download/v$VERSION/trailerfin_rust-${PLATFORM}-unknown-linux-musl.tar.gz && \
    tar -xzf /tmp/trailerfin_rust.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/trailerfin_rust && \
    rm -rf /tmp/trailerfin_rust*

FROM --platform=$TARGETARCH gcr.io/distroless/static-debian12:latest

LABEL org.opencontainers.image.source = "https://github.com/ipromknight/trailerfin_rust"
LABEL org.opencontainers.image.based_on = "https://github.com/Pukabyte/trailerfin"
LABEL org.opencontainers.image.title = "trailerfin_rust"
LABEL org.opencontainers.image.authors = "ipromknight"
LABEL org.opencontainers.image.documentation = "https://github.com/ipromknight/trailerfin_rust/blob/main/README.md"

COPY --from=cloner /usr/local/bin/trailerfin_rust /usr/bin/trailerfin_rust

ENTRYPOINT ["/usr/bin/trailerfin_rust"]
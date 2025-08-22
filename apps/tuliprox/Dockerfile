FROM alpine AS cloner

ARG VERSION

WORKDIR /src

RUN apk add --update --no-cache git && \
    git clone -b v$VERSION https://github.com/euzu/tuliprox.git .

FROM rust:bookworm AS rust-build

ARG RUST_TARGET=x86_64-unknown-linux-musl

RUN apt-get update && apt-get install -y --no-install-recommends pkg-config musl-tools libssl-dev
RUN rustup update && rustup target add $RUST_TARGET
ENV RUSTFLAGS='--remap-path-prefix $HOME=~ -C target-feature=+crt-static'

COPY --from=cloner /src/Cargo.toml /src/Cargo.lock /src/
COPY --from=cloner /src/backend/Cargo.toml /src/backend/
COPY --from=cloner /src/frontend/Cargo.toml /src/frontend/
COPY --from=cloner /src/shared/Cargo.toml /src/shared/

RUN mkdir -p /src/src /src/backend/src /src/frontend/src /src/shared/src && \
    echo "fn main() {}" > /src/src/main.rs && \
    echo "fn main() {}" > /src/backend/src/main.rs && \
    echo "fn main() {}" > /src/frontend/src/main.rs && \
    echo "pub fn dummy() {}" > /src/shared/src/lib.rs

WORKDIR /src

RUN cargo build -p tuliprox --target $RUST_TARGET --release || true
RUN cargo build -p shared --target $RUST_TARGET --release || true

COPY --from=cloner /src/ .

RUN cargo build -p tuliprox --target $RUST_TARGET --release

FROM rust:bookworm AS trunk-build

ARG RUST_TARGET=x86_64-unknown-linux-musl

RUN apt-get update && apt-get install -y --no-install-recommends \
  pkg-config libssl-dev curl libclang-dev binaryen

RUN rustup target add wasm32-unknown-unknown
RUN cargo install --locked trunk wasm-bindgen-cli

COPY --from=cloner /src/Cargo.toml /src/Cargo.lock /src/
COPY --from=cloner /src/frontend/Cargo.toml /src/frontend/Trunk.toml /src/frontend/
COPY --from=cloner /src/shared/Cargo.toml /src/shared/

RUN mkdir -p /src/frontend/src /src/shared/src && \
    echo "fn main() {}" > /src/frontend/src/main.rs && \
    echo "pub fn dummy() {}" > /src/shared/src/lib.rs

WORKDIR /src/frontend

RUN cargo build --target wasm32-unknown-unknown --release || true

COPY --from=cloner /src/ /src/

WORKDIR /src/frontend

RUN trunk build --release

# -----------------------------------------------------------------
# Stage 3: Build video resources with ffmpeg
# -----------------------------------------------------------------
FROM linuxserver/ffmpeg:latest AS resource-build

COPY --from=cloner /src/resources /src/resources

RUN ffmpeg -loop 1 -i /src/resources/channel_unavailable.jpg -t 10 -r 1 -an \
    -vf "scale=1920:1080" \
    -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p \
    /src/resources/channel_unavailable.ts && \
  ffmpeg -loop 1 -i /src/resources/user_connections_exhausted.jpg -t 10 -r 1 -an \
    -vf "scale=1920:1080" \
    -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p \
    /src/resources/user_connections_exhausted.ts && \
  ffmpeg -loop 1 -i /src/resources/provider_connections_exhausted.jpg -t 10 -r 1 -an \
    -vf "scale=1920:1080" \
    -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p \
    /src/resources/provider_connections_exhausted.ts && \
   ffmpeg -loop 1 -i /src/resources/user_account_expired.jpg -t 10 -r 1 -an \
     -vf "scale=1920:1080" \
     -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p \
     /src/resources/user_account_expired.ts

FROM alpine:latest AS tz-prep

ARG TZ=UTC
ENV TZ=${TZ}

RUN apk add --no-cache tzdata \
  && mkdir -p /output/etc \
  && mkdir -p /output/usr/share \
  && cp -r /usr/share/zoneinfo /output/usr/share/zoneinfo \
  && ln -sf /usr/share/zoneinfo/${TZ} /output/etc/localtime


FROM ghcr.io/ipromknight/alpine:rolling

ARG RUST_TARGET=x86_64-unknown-linux-musl
ARG TZ=UTC
ENV TZ=${TZ}

RUN apk add --no-cache bash curl ca-certificates tini

COPY --from=tz-prep /output/usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=rust-build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

RUN ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

WORKDIR /app
COPY --from=rust-build /src/target/${RUST_TARGET}/release/tuliprox /app/tuliprox
COPY --from=trunk-build /src/frontend/dist /app/web
COPY --from=resource-build /src/resources /app/resources

USER 568

EXPOSE 8901

COPY --chmod=0755 apps/tuliprox/promknight-entrypoint.sh /promknight-entrypoint.sh
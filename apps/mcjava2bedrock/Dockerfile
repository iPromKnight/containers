FROM debian:bookworm-slim

ARG VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        curl \
        unzip \
        zip \
        jq \
        moreutils \
        imagemagick \
        nodejs \
        npm \
        git \
        uuid-runtime && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g spritesheet-js

WORKDIR /app

COPY --chmod=0755 ./apps/mcjava2bedrock/root /

ENTRYPOINT ["/promknight-entrypoint.sh"]
CMD []
FROM alpine AS cloner
ARG VERSION
RUN apk add --update --no-cache git && \
    git clone -b $VERSION https://github.com/Gaisberg/orionzb.git /source

# Frontend/backend are all node — single multi-stage build, no cross-compile pain
FROM --platform=$BUILDPLATFORM node:20-alpine AS builder

ARG VERSION=0.0.0
ARG CHANNEL=dev

WORKDIR /app

RUN npm install -g pnpm@latest

COPY --from=cloner /source/package.json /source/pnpm-lock.yaml* /source/tsconfig.json ./

# Install all deps (incl. dev for tsc)
RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
    pnpm install --frozen-lockfile

COPY --from=cloner /source/src ./src

# Compile TypeScript -> dist/
RUN pnpm run build

# Prune dev deps from node_modules so the final image only ships runtime deps
RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
    pnpm prune --prod

# Final image — same base family as decypharr/altmount
FROM ghcr.io/ipromknight/alpine:rolling

ARG VERSION=0.0.0
ARG CHANNEL=dev

LABEL version="${VERSION}-${CHANNEL}"
LABEL org.opencontainers.image.source="https://github.com/Gaisberg/orionzb"
LABEL org.opencontainers.image.title="orionzb"
LABEL org.opencontainers.image.authors="Gaisberg"
LABEL org.opencontainers.image.documentation="https://github.com/Gaisberg/orionzb/blob/main/README.md"

# Node runtime — alpine ships it as `nodejs`
RUN apk add --no-cache nodejs

WORKDIR /app

# Copy compiled JS + pruned production node_modules
COPY --from=builder --chown=568:568 /app/dist          /app/dist
COPY --from=builder --chown=568:568 /app/node_modules  /app/node_modules
COPY --from=builder --chown=568:568 /app/package.json  /app/package.json

# Directory scaffold for runtime state / config
RUN install -d -o 568 -g 568 /config

ENV NODE_ENV=production
ENV SERVER_PORT=3000
ENV SERVER_HOST=0.0.0.0
EXPOSE 3000

USER 568

# Seed config for goss/web tests — placeholder API keys so validateConfig() passes
COPY --chown=568:568 apps/orionzb/config.json /config/config.json

COPY --chmod=0755 apps/orionzb/promknight-entrypoint.sh /promknight-entrypoint.sh
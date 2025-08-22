# Get upstream code
FROM alpine:latest AS cloner
ARG VERSION

RUN apk update && apk upgrade && \
    apk add --no-cache git

RUN git clone -b $VERSION  https://github.com/Dictionarry-Hub/profilarr.git /source

### STAGE 1: Build Profilarr ###
FROM node:20-alpine AS build
COPY --from=cloner /source /source
WORKDIR /source

RUN cd ./frontend && \
    npm ci && \
    npm run build && \
    cd .. && \
    mkdir -p dist/backend dist/static && \
    cp -r frontend/dist/* dist/static/ && \
    cp -r backend/* dist/backend/ && \
    cp backend/requirements.txt dist/

### STAGE 2: Final Image ###
FROM ghcr.io/ipromknight/ubuntu:rolling

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG VERSION
ARG CHANNEL

RUN apt-get update && \
    apt-get install -y git python3.9 pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /source/dist/backend/app ./app
COPY --from=build /source/dist/static ./app/static
COPY --from=build /source/dist/requirements.txt .

RUN pip install --upgrade pip wheel \
    && pip install --no-cache-dir -r requirements.txt

RUN chown -R 568:568 /app

LABEL org.opencontainers.image.authors="Dictionarry dictionarry@pm.me"
LABEL org.opencontainers.image.description="Profilarr - Profile manager for *arr apps"
LABEL org.opencontainers.image.source="https://github.com/Dictionarry-Hub/profilarr"
LABEL org.opencontainers.image.title="Profilarr"
LABEL org.opencontainers.image.version="release"

EXPOSE 6868

USER 568

COPY --chmod=0755 apps/profilarr/promknight-entrypoint.sh /promknight-entrypoint.sh
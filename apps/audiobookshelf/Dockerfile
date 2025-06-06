# Get upstream code
FROM alpine:latest AS cloner
ARG VERSION

RUN apk update && apk upgrade && \
    apk add --no-cache git

RUN git clone -b $VERSION  https://github.com/advplyr/audiobookshelf.git /source

### STAGE 0: Build client ###
FROM node:20-alpine AS build
WORKDIR /client
COPY --from=cloner /source/client /client
RUN npm ci && npm cache clean --force
RUN npm run generate

### STAGE 1: Build server ###
FROM node:20-alpine

ENV NODE_ENV=production

RUN apk update && \
    apk add --no-cache --update \
    curl \
    bash \
    tzdata \
    ffmpeg \
    make \
    gcompat \
    python3 \
    g++ \
    tini 


COPY --from=build /client/dist /client/dist
COPY --from=cloner /source/index.js /source/package* /
COPY --from=cloner /source/server server

RUN npm ci --only=production

RUN apk del make python3 g++

ENV PORT=8000

COPY --chmod=0755 apps/audiobookshelf/promknight-entrypoint.sh /promknight-entrypoint.sh

ENTRYPOINT ["/promknight-entrypoint.sh"]


ARG VERSION
FROM qmcgaw/gluetun:v${VERSION} AS upstream

RUN apk --no-cache add bind-tools curl bash

COPY --chmod=0755 ./apps/gluetun/promknight-entrypoint.sh /promknight-entrypoint.sh
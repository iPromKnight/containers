ARG VERSION
FROM qmcgaw/gluetun:v${VERSION} as upstream

RUN apk --no-cache add bind-tools curl

COPY --chmod=0755 ./apps/gluetun/promknight-entrypoint.sh /promknight-entrypoint.sh
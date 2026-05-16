ARG VERSION
FROM qmcgaw/gluetun:v${VERSION} as upstream

# `jq` for pick-servers.sh (parses the proton-gluetun-updater cache),
# `curl` for the watchdog probe + Gluetun control-server PUTs,
# `bind-tools` for DNS-helper paths in promknight-entrypoint.sh,
# `bash` because promknight-entrypoint.sh uses bash features ([[ ]], etc.).
RUN apk --no-cache add bash bind-tools curl jq

COPY --chmod=0755 ./apps/gluetun/promknight-entrypoint.sh /promknight-entrypoint.sh
COPY --chmod=0755 ./apps/gluetun/pick-servers.sh /pick-servers.sh
COPY --chmod=0755 ./apps/gluetun/watchdog.sh /watchdog.sh
COPY --chmod=0755 ./apps/gluetun/probe-status.sh /probe-status.sh
COPY --chmod=0755 ./apps/gluetun/probe-egress.sh /probe-egress.sh

# Make /promknight-entrypoint.sh the default ENTRYPOINT so the helmreleases
# don't need to override `command:` to invoke it. The script execs into
# upstream's /gluetun-entrypoint at the end, preserving normal Gluetun behaviour.
ENTRYPOINT ["/promknight-entrypoint.sh"]

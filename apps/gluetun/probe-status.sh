#!/bin/sh
# K8s liveness probe for the Gluetun container.
#
# Asks Gluetun's control server for its self-reported VPN status and exits 0
# iff the tunnel is in the "running" state. Sends the X-API-Key header when
# GLUETUN_CONTROL_APIKEY is set (required because our config.toml uses
# auth = "apikey" to silence Gluetun's deprecation WARN on every probe).
#
# Used via:
#     probes:
#       liveness:
#         custom: true
#         spec:
#           exec:
#             command: ["/probe-status.sh"]
#
# Inputs (env, all optional):
#   GLUETUN_CONTROL_APIKEY      X-API-Key value, empty if no auth
#   PROBE_CONTROL_URL           control server base, default http://localhost:8000

set -eu

CONTROL_URL="${PROBE_CONTROL_URL:-http://localhost:8000}"
APIKEY="${GLUETUN_CONTROL_APIKEY:-}"

if [ -n "$APIKEY" ]; then
    status=$(curl -s -H "X-API-Key: $APIKEY" "$CONTROL_URL/v1/vpn/status" || echo "")
else
    status=$(curl -s "$CONTROL_URL/v1/vpn/status" || echo "")
fi

echo "$status" | grep -q '"status":"running"'

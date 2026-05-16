#!/bin/sh
# Gluetun watchdog — probes an external URL through the tunnel and cycles
# the VPN via Gluetun's control server (PUT /v1/vpn/status) if a configurable
# number of consecutive probes fail.
#
# Designed to run as a sidecar in the same pod as Gluetun, sharing the pod's
# network namespace, so curl egresses over wg0.
#
# Inputs (env, all optional except WATCHDOG_PROBE_URL):
#   WATCHDOG_PROBE_URL          URL to probe (required, no default)
#   WATCHDOG_INTERVAL           seconds between probes, default 10
#   WATCHDOG_MAX_FAILS          consecutive failures before cycling, default 2
#   WATCHDOG_RECOVERY_SLEEP     seconds of silence after a cycle, default 20
#   WATCHDOG_TIMEOUT            curl --max-time in seconds, default 10
#   WATCHDOG_CONTROL_URL        Gluetun control server base, default http://localhost:8000

set -eu

URL="${WATCHDOG_PROBE_URL:?WATCHDOG_PROBE_URL must be set}"
INTERVAL="${WATCHDOG_INTERVAL:-10}"
MAX_FAILS="${WATCHDOG_MAX_FAILS:-2}"
RECOVERY_SLEEP="${WATCHDOG_RECOVERY_SLEEP:-20}"
TIMEOUT="${WATCHDOG_TIMEOUT:-10}"
CONTROL_URL="${WATCHDOG_CONTROL_URL:-http://localhost:8000}"

echo "watchdog: probing $URL every ${INTERVAL}s (max $MAX_FAILS consecutive failures, timeout ${TIMEOUT}s)"

# Startup grace — let Gluetun finish bringing the tunnel up before we probe.
sleep "$INTERVAL"

fails=0
while sleep "$INTERVAL"; do
    if curl -fsSL --max-time "$TIMEOUT" -o /dev/null "$URL"; then
        if [ "$fails" -gt 0 ]; then
            echo "watchdog: probe recovered"
        fi
        fails=0
        continue
    fi

    fails=$((fails + 1))
    echo "watchdog: probe failed ($fails/$MAX_FAILS)"

    if [ "$fails" -ge "$MAX_FAILS" ]; then
        echo "watchdog: cycling Gluetun via $CONTROL_URL"
        curl -fsS -X PUT -H 'Content-Type: application/json' \
            -d '{"status":"stopped"}' \
            "$CONTROL_URL/v1/vpn/status" || true
        sleep 2
        curl -fsS -X PUT -H 'Content-Type: application/json' \
            -d '{"status":"running"}' \
            "$CONTROL_URL/v1/vpn/status" || true
        fails=0
        sleep "$RECOVERY_SLEEP"
    fi
done

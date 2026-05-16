#!/bin/bash
# Gluetun watchdog — probes a host:port through the tunnel using bash's
# built-in /dev/tcp pseudo-device (no extra binaries needed, no protocol
# overhead, ~50ms when healthy). On a configurable number of consecutive
# failures, cycles the VPN via Gluetun's control server.
#
# Designed to run in the background inside the Gluetun container itself —
# launched by /promknight-entrypoint.sh before exec'ing into upstream's
# /gluetun-entrypoint. Shares Gluetun's network namespace so probes go via
# the tunnel.
#
# Inputs (env, all optional):
#   WATCHDOG_PROBE_TARGET       host:port to TCP-connect, default 1.1.1.1:443
#   WATCHDOG_INTERVAL           seconds between probes, default 20
#   WATCHDOG_MAX_FAILS          consecutive failures before cycling, default 3
#   WATCHDOG_RECOVERY_SLEEP     seconds of silence after a cycle, default 30
#   WATCHDOG_TIMEOUT            connect timeout in seconds, default 5
#   WATCHDOG_CONTROL_URL        Gluetun control server, default http://localhost:8000

set -eu

TARGET="${WATCHDOG_PROBE_TARGET:-1.1.1.1:443}"
INTERVAL="${WATCHDOG_INTERVAL:-20}"
MAX_FAILS="${WATCHDOG_MAX_FAILS:-3}"
RECOVERY_SLEEP="${WATCHDOG_RECOVERY_SLEEP:-30}"
TIMEOUT="${WATCHDOG_TIMEOUT:-5}"
CONTROL_URL="${WATCHDOG_CONTROL_URL:-http://localhost:8000}"

# Split host:port — /dev/tcp/<host>/<port> needs them separately.
HOST="${TARGET%:*}"
PORT="${TARGET##*:}"

if [[ -z "$HOST" || -z "$PORT" || "$HOST" = "$PORT" ]]; then
    echo "watchdog: WATCHDOG_PROBE_TARGET must be host:port, got '$TARGET'" >&2
    exit 1
fi

probe() {
    # Open a TCP connection to host:port, immediately close it. `timeout`
    # bounds the entire attempt; redirecting fd 3 to /dev/tcp triggers the
    # connect, redirecting it back to &- closes the FD cleanly.
    timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/$HOST/$PORT && exec 3<&-" 2>/dev/null
}

cycle_gluetun() {
    echo "watchdog: cycling Gluetun via $CONTROL_URL"
    curl -fsS -X PUT -H 'Content-Type: application/json' \
        -d '{"status":"stopped"}' \
        "$CONTROL_URL/v1/vpn/status" || true
    sleep 2
    curl -fsS -X PUT -H 'Content-Type: application/json' \
        -d '{"status":"running"}' \
        "$CONTROL_URL/v1/vpn/status" || true
}

echo "watchdog: probing tcp://$HOST:$PORT every ${INTERVAL}s (max $MAX_FAILS consecutive failures, timeout ${TIMEOUT}s)"

# Startup grace — let Gluetun finish bringing the tunnel up before we probe.
sleep "$INTERVAL"

fails=0
while sleep "$INTERVAL"; do
    if probe; then
        if (( fails > 0 )); then
            echo "watchdog: probe recovered"
        fi
        fails=0
        continue
    fi

    fails=$((fails + 1))
    echo "watchdog: probe failed ($fails/$MAX_FAILS)"

    if (( fails >= MAX_FAILS )); then
        cycle_gluetun
        fails=0
        sleep "$RECOVERY_SLEEP"
    fi
done

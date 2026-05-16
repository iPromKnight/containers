#!/bin/bash
# Startup quality check for Gluetun — runs after the tunnel is up.
#
# Measures TCP retransmit rate during a brief download burst. If the rate
# exceeds the threshold, cycles Gluetun via the control server (which picks
# a fresh endpoint from the SERVER_NAMES pool) and re-tests. Up to N cycles
# before giving up and letting the pod run on whatever it lands on (better
# to be slightly lossy than crash-loop forever on a bad night).
#
# Runs in the background from /promknight-entrypoint.sh AFTER Gluetun's
# main process is execed, so it sees a live tunnel. Sleeps long enough for
# the tunnel handshake to complete before measuring.
#
# Inputs (env, all optional):
#   QUALITY_CHECK_DISABLED        if non-empty, skip entirely
#   QUALITY_CHECK_URL             test download URL, default 10MB Cloudflare endpoint
#   QUALITY_CHECK_MAX_RETRANSMIT  retransmit% threshold (integer), default 2
#   QUALITY_CHECK_MAX_CYCLES      max cycles before giving up, default 3
#   QUALITY_CHECK_STARTUP_WAIT    seconds to wait for tunnel before testing, default 15
#   QUALITY_CHECK_RECOVERY_WAIT   seconds after a cycle before re-testing, default 20
#   QUALITY_CHECK_TIMEOUT         curl --max-time for the test, default 15
#   QUALITY_CHECK_ALLOW_POOL_ESCAPE  if non-empty, when all MAX_CYCLES attempts
#                                    fail with the picker's SERVER_NAMES pool,
#                                    drop the pin and try once more from the
#                                    full SERVER_COUNTRIES pool. Last-resort
#                                    escape hatch when pick-servers.sh has
#                                    landed us on a pool of uniformly bad
#                                    endpoints (e.g. all 10 picks share a
#                                    degraded peering path).
#   GLUETUN_CONTROL_APIKEY        for control-server PUTs

set -u

if [[ -n "${QUALITY_CHECK_DISABLED:-}" ]]; then
    echo "quality-check: QUALITY_CHECK_DISABLED is set — skipping"
    exit 0
fi

URL="${QUALITY_CHECK_URL:-https://speed.cloudflare.com/__down?bytes=10000000}"
THRESHOLD_PCT="${QUALITY_CHECK_MAX_RETRANSMIT:-2}"
MAX_CYCLES="${QUALITY_CHECK_MAX_CYCLES:-3}"
STARTUP_WAIT="${QUALITY_CHECK_STARTUP_WAIT:-15}"
RECOVERY_WAIT="${QUALITY_CHECK_RECOVERY_WAIT:-20}"
CURL_TIMEOUT="${QUALITY_CHECK_TIMEOUT:-15}"
CONTROL_URL="${WATCHDOG_CONTROL_URL:-http://localhost:8000}"
APIKEY="${GLUETUN_CONTROL_APIKEY:-}"

if [[ -n "$APIKEY" ]]; then
    AUTH_HEADER=(-H "X-API-Key: $APIKEY")
else
    AUTH_HEADER=()
fi

cycle_gluetun() {
    echo "quality-check: cycling Gluetun to pick a fresh endpoint"
    curl -fsS -X PUT "${AUTH_HEADER[@]}" -H 'Content-Type: application/json' \
        -d '{"status":"stopped"}' \
        "$CONTROL_URL/v1/vpn/status" >/dev/null 2>&1 || true
    sleep 2
    curl -fsS -X PUT "${AUTH_HEADER[@]}" -H 'Content-Type: application/json' \
        -d '{"status":"running"}' \
        "$CONTROL_URL/v1/vpn/status" >/dev/null 2>&1 || true
}

# Measure retransmit rate via /proc/net/snmp delta during a small download.
# This is cheaper and more accurate than capturing with tcpdump + tshark:
# the kernel maintains a running counter of TCP retransmits, we just read
# the delta over a single curl execution.
measure_retransmit_pct() {
    local before_retrans before_out after_retrans after_out
    local out_delta retrans_delta pct

    # Snapshot before
    read -r _ _ _ _ _ _ _ _ _ _ before_out before_retrans _ <<< \
        "$(grep -E '^Tcp:' /proc/net/snmp | tail -1)"

    # Do the download — discard body, just want to push packets through
    if ! curl -fsS --max-time "$CURL_TIMEOUT" -o /dev/null "$URL" 2>/dev/null; then
        echo "quality-check: download failed (curl error) — treating as bad"
        echo "100"
        return
    fi

    # Snapshot after
    read -r _ _ _ _ _ _ _ _ _ _ after_out after_retrans _ <<< \
        "$(grep -E '^Tcp:' /proc/net/snmp | tail -1)"

    out_delta=$((after_out - before_out))
    retrans_delta=$((after_retrans - before_retrans))

    # Avoid divide-by-zero if curl somehow sent zero packets
    if [[ "$out_delta" -lt 100 ]]; then
        echo "quality-check: too few packets (out_delta=$out_delta) — inconclusive, treating as ok"
        echo "0"
        return
    fi

    # Integer percent — bash can't do float, multiply first
    pct=$((retrans_delta * 100 / out_delta))
    echo "$pct"
}

echo "quality-check: waiting ${STARTUP_WAIT}s for tunnel to establish..."
sleep "$STARTUP_WAIT"

attempt=0
while (( attempt <= MAX_CYCLES )); do
    if (( attempt > 0 )); then
        echo "quality-check: attempt $attempt of $MAX_CYCLES after cycle"
    else
        echo "quality-check: initial probe"
    fi

    pct=$(measure_retransmit_pct)
    echo "quality-check: retransmit rate ${pct}% (threshold ${THRESHOLD_PCT}%)"

    if (( pct <= THRESHOLD_PCT )); then
        echo "quality-check: endpoint is healthy, exiting"
        exit 0
    fi

    if (( attempt == MAX_CYCLES )); then
        # Escape hatch: if the picker pinned SERVER_NAMES and we've failed to
        # find a healthy endpoint within it, drop the pin and try once more
        # from the full country pool. Opt-in via QUALITY_CHECK_ALLOW_POOL_ESCAPE.
        if [[ -n "${QUALITY_CHECK_ALLOW_POOL_ESCAPE:-}" ]] \
           && [[ -f /shared/env ]] \
           && grep -q SERVER_NAMES /shared/env; then
            echo "quality-check: max cycles reached on picker pool, escape hatch enabled —"
            echo "quality-check: clearing SERVER_NAMES pin and falling back to full country pool"
            : > /shared/env
            cycle_gluetun
            echo "quality-check: waiting ${RECOVERY_WAIT}s for new tunnel from full pool..."
            sleep "$RECOVERY_WAIT"

            pct=$(measure_retransmit_pct)
            echo "quality-check: full-pool retransmit rate ${pct}% (threshold ${THRESHOLD_PCT}%)"
            if (( pct <= THRESHOLD_PCT )); then
                echo "quality-check: full pool gave a healthy endpoint, exiting"
                exit 0
            fi
            echo "quality-check: full pool also unhealthy — giving up"
            exit 0
        fi

        echo "quality-check: max cycles reached, giving up — letting pod run on current endpoint"
        exit 0
    fi

    cycle_gluetun
    echo "quality-check: waiting ${RECOVERY_WAIT}s for new tunnel..."
    sleep "$RECOVERY_WAIT"
    attempt=$((attempt + 1))
done

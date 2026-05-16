#!/bin/bash
# Real-egress liveness probe for the Gluetun container.
#
# Tries TCP-connect via /dev/tcp to a list of anycast targets through the
# tunnel. Exits 0 if any target responds; non-zero if all fail.
#
# Used as a k8s liveness probe. With failureThreshold=6 + periodSeconds=30,
# a sustained 3-minute egress failure triggers kubelet to restart the pod —
# the safety net for the rare case where Gluetun's own watchdog can't
# recover the tunnel.
#
# We probe multiple targets and exit on the first success because we care
# about "is the tunnel passing real traffic?", not "is one specific
# endpoint up?". A single target failing in isolation is not a tunnel
# problem; all of them failing in sequence is.
#
# Inputs (env, all optional):
#   PROBE_TARGETS  comma-separated host:port list, default 1.1.1.1:443,8.8.8.8:443,9.9.9.9:443
#   PROBE_TIMEOUT  seconds per target, default 4

set -u

TARGETS="${PROBE_TARGETS:-1.1.1.1:443,8.8.8.8:443,9.9.9.9:443}"
TIMEOUT="${PROBE_TIMEOUT:-4}"

IFS=',' read -ra TARGET_LIST <<< "$TARGETS"

for target in "${TARGET_LIST[@]}"; do
    host="${target%:*}"
    port="${target##*:}"
    if timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/$host/$port && exec 3<&-" 2>/dev/null; then
        # First reachable target = tunnel is passing real traffic. Healthy.
        exit 0
    fi
done

# All targets failed. Tunnel is not passing traffic.
exit 1

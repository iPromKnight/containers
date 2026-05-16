#!/bin/bash

set -e

cat << "EOF"

▐▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▌
▐                                                                                       ▌
▐  ██▓███   ██▀███   ▒█████   ███▄ ▄███▓ ██ ▄█▀ ███▄    █  ██▓  ▄████  ██░ ██ ▄▄▄█████▓ ▌
▐ ▓██░  ██▒▓██ ▒ ██▒▒██▒  ██▒▓██▒▀█▀ ██▒ ██▄█▒  ██ ▀█   █ ▓██▒ ██▒ ▀█▒▓██░ ██▒▓  ██▒ ▓▒ ▌
▐ ▓██░ ██▓▒▓██ ░▄█ ▒▒██░  ██▒▓██    ▓██░▓███▄░ ▓██  ▀█ ██▒▒██▒▒██░▄▄▄░▒██▀▀██░▒ ▓██░ ▒░ ▌
▐ ▒██▄█▓▒ ▒▒██▀▀█▄  ▒██   ██░▒██    ▒██ ▓██ █▄ ▓██▒  ▐▌██▒░██░░▓█  ██▓░▓█ ░██ ░ ▓██▓ ░  ▌
▐ ▒██▒ ░  ░░██▓ ▒██▒░ ████▓▒░▒██▒   ░██▒▒██▒ █▄▒██░   ▓██░░██░░▒▓███▀▒░▓█▒░██▓  ▒██▒ ░  ▌
▐ ▒▓▒░ ░  ░░ ▒▓ ░▒▓░░ ▒░▒░▒░ ░ ▒░   ░  ░▒ ▒▒ ▓▒░ ▒░   ▒ ▒ ░▓   ░▒   ▒  ▒ ░░▒░▒  ▒ ░░    ▌
▐ ░▒ ░       ░▒ ░ ▒░  ░ ▒ ▒░ ░  ░      ░░ ░▒ ▒░░ ░░   ░ ▒░ ▒ ░  ░   ░  ▒ ░▒░ ░    ░     ▌
▐ ░░         ░░   ░ ░ ░ ░ ▒  ░      ░   ░ ░░ ░    ░   ░ ░  ▒ ░░ ░   ░  ░  ░░ ░  ░       ▌
▐             ░         ░ ░         ░   ░  ░            ░  ░        ░  ░  ░  ░          ▌
▐                                                                                       ▌
▐ Gluetun                                                                               ▌
▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌

EOF

# Cilium occasionally leaves stale WireGuard routing rules (table 51820) in
# the pod's netns after a pod restart — Gluetun then fails to set up its own
# WG table and the tunnel never establishes. Clearing them early is a no-op
# on first boot and a fix on restart. Failures are ignored because they mean
# "rule didn't exist", which is the happy path.
(ip rule del table 51820; ip -6 rule del table 51820) 2>/dev/null || true

# Pick the lowest-load Proton servers from the proton-gluetun-updater cache
# and write SERVER_NAMES to /shared/env. Falls back gracefully (no SERVER_NAMES
# set) if the cache isn't mounted or is empty — see /pick-servers.sh for the
# cache-miss policy. Must run *before* sourcing /shared/env below so the
# freshly-written SERVER_NAMES enters this shell's env.
if [[ -x /pick-servers.sh ]]; then
    /pick-servers.sh || echo "pick-servers: exited non-zero, continuing without pin"
fi

# If we have snuck a VPN_ENDPOINT_IP value into /shared/VPN_ENDPOINT_IP, then use that instead of the current ENV VAR
if [[ -f /shared/VPN_ENDPOINT_IP ]]; then
    export VPN_ENDPOINT_IP=$(cat /shared/VPN_ENDPOINT_IP)
fi

# Allow us to write env files to /shared
if [[ -f /shared/env ]]; then
    source /shared/env
fi

# Launch the watchdog in the background. It TCP-probes WATCHDOG_PROBE_TARGET
# through the tunnel via bash's /dev/tcp pseudo-device and cycles Gluetun via
# the control server on repeated failures. Lives in this container so we don't
# need a separate sidecar — when Gluetun (which becomes PID 1 below via exec)
# exits, the watchdog dies with it.
# Skip when WATCHDOG_DISABLED is truthy (escape hatch for debugging or for
# PIA-based deployments that don't need the cycling behaviour).
if [[ -x /watchdog.sh ]] && [[ -z "${WATCHDOG_DISABLED:-}" ]]; then
    /watchdog.sh 2>&1 | sed 's/^/[watchdog] /' &
    echo "watchdog launched in background (pid $!)"
fi

# If we're in "sleep mode", then don't actually, just do nothing (useful when we control how a pod will run based on an env var)
if [[ ! -z "$GLUETUN_DISABLED" ]];
then
    echo "GLUETUN_DISABLED env var set, doing nothing.."
    sleep infinity
else
    exec \
        /gluetun-entrypoint
fi
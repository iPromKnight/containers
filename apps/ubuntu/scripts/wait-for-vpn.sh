#!/usr/bin/env bash

TIMEOUT_SECONDS=2
SLEEP_SECONDS=2

if [[ "${WAIT_FOR_VPN:-false}" == "true" ]]; then
    echo "🔒 Waiting for VPN to be connected..."
    while ! grep -s -q "connected" /shared/vpnstatus; do
        echo "VPN not connected yet..."
        sleep "$SLEEP_SECONDS"
    done
    echo "✅ VPN Connected. Starting application..."
fi

if [[ "${WAIT_FOR_GLUETUN:-false}" == "true" ]]; then
    echo "🌐 Waiting for Gluetun to be ready..."
    until timeout "${TIMEOUT_SECONDS}s" bash -c 'curl -s http://localhost:8000/v1/vpn/status | grep -q running'; do
        echo "Gluetun not ready yet..."
        sleep "$SLEEP_SECONDS"
    done
    echo "✅ Gluetun is ready. Starting application..."
fi
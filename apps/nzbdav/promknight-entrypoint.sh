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
▐ NzbDav                                                                                ▌
▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌

EOF

CONFIG_PATH="${CONFIG_PATH:-/config}"
BACKEND_URL="${BACKEND_URL:-http://localhost:8080}"
MAX_BACKEND_HEALTH_RETRIES="${MAX_BACKEND_HEALTH_RETRIES:-30}"
MAX_BACKEND_HEALTH_RETRY_DELAY="${MAX_BACKEND_HEALTH_RETRY_DELAY:-1}"

# The SSR frontend talks to the backend with a shared API key. Generate a
# random one per-start if not supplied — the frontend reads the same env var.
if [ -z "${FRONTEND_BACKEND_API_KEY}" ]; then
    FRONTEND_BACKEND_API_KEY=$(head -c 32 /dev/urandom | hexdump -ve '1/1 "%.2x"')
    export FRONTEND_BACKEND_API_KEY
fi

# Re-own /config if k8s mounted it as something other than 568:568. db.sqlite
# is the canonical marker — if it's already correct, skip the recursive chown.
chown 568:568 "$CONFIG_PATH"
if [ -f "$CONFIG_PATH/db.sqlite" ]; then
    DB_UID=$(stat -c '%u' "$CONFIG_PATH/db.sqlite")
    DB_GID=$(stat -c '%g' "$CONFIG_PATH/db.sqlite")
    if [ "$DB_UID" -ne 568 ] || [ "$DB_GID" -ne 568 ]; then
        echo "Fixing ownership of $CONFIG_PATH (was ${DB_UID}:${DB_GID})"
        chown -R 568:568 "$CONFIG_PATH"
    fi
fi

# Run schema migration first; the app refuses to start on a stale schema.
cd /app/backend
echo "Running database migration..."
su-exec 568:568 ./NzbWebDAV --db-migration

# Backend (.NET ASP.NET Core, listens on :8080)
su-exec 568:568 ./NzbWebDAV &
BACKEND_PID=$!

# Wait for backend /health before launching the SSR frontend — the frontend's
# first render hits the backend, so starting them in parallel races and 502s.
echo "Waiting for backend at $BACKEND_URL/health ..."
i=0
while true; do
    if curl -sf -o /dev/null "$BACKEND_URL/health"; then
        echo "Backend healthy."
        break
    fi
    i=$((i+1))
    if [ "$i" -ge "$MAX_BACKEND_HEALTH_RETRIES" ]; then
        echo "Backend failed health check after ${MAX_BACKEND_HEALTH_RETRIES} attempts." >&2
        kill "$BACKEND_PID" 2>/dev/null || true
        exit 1
    fi
    sleep "$MAX_BACKEND_HEALTH_RETRY_DELAY"
done

# Frontend (Node SSR, listens on :3000)
cd /app/frontend
su-exec 568:568 npm run start &
FRONTEND_PID=$!

# Forward signals so k8s SIGTERM stops both children cleanly.
terminate() {
    echo "Received termination signal, stopping nzbdav..."
    kill "$BACKEND_PID"  2>/dev/null || true
    kill "$FRONTEND_PID" 2>/dev/null || true
    wait
    exit 0
}
trap terminate TERM INT

# Exit as soon as either process dies — k8s restart policy handles recovery.
while kill -0 "$BACKEND_PID" 2>/dev/null && kill -0 "$FRONTEND_PID" 2>/dev/null; do
    sleep 1
done

if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo "Backend exited; stopping frontend."
    kill "$FRONTEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" || EXIT_CODE=$?
else
    echo "Frontend exited; stopping backend."
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$FRONTEND_PID" || EXIT_CODE=$?
fi
exit "${EXIT_CODE:-0}"

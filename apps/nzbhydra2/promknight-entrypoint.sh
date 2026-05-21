#!/usr/bin/env bash

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
▐ NZBHydra2                                                                             ▌
▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌

EOF

# Invoke the upstream Python wrapper. It sets the -DfromWrapper=true
# sysprop core requires, generates the internal IPC key, and handles the
# control-code restart loop (UI "Restart" emits exit 22; restore emits 33;
# crash emits 1/99 with a built-in loop guard). Heap and other JVM tuning
# come from /config/nzbhydra.yml, so the user can change them from the UI.
# Auto-update is disabled because Docker is our update mechanism.
cd /app
export NZBHYDRA_DISABLE_UPDATE_ON_SHUTDOWN=1
exec \
    python3 /app/nzbhydra2wrapperPy3.py \
        --datafolder /config \
        --nobrowser \
        "$@"

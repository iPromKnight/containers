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
▐ Ubuntu Base Image                                                                     ▌
▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌

EOF

if [[ $# -eq 0 ]]; then
  echo "No command provided — defaulting to tail -f /dev/null"
  set -- tail -f /dev/null
fi

exec /usr/bin/tini -- "$@"
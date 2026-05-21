#!/bin/bash

set -e

source "/prom_scripts/wait-for-vpn.sh"
source "/prom_scripts/wait-for-urls.sh"
source "/prom_scripts/wait-for-mounts.sh"
source "/prom_scripts/umask.sh"
source "/prom_scripts/extra-scripts.sh"

exec /promknight-entrypoint.sh "$@"
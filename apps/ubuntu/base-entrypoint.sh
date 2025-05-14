#!/bin/bash

set -e

echo "Based on work by funky penguin @elfhosted/containers"

source "/scripts/wait-for-vpn.sh"
source "/scripts/wait-for-urls.sh"
source "/scripts/wait-for-mounts.sh"
source "/scripts/umask.sh"
source "/scripts/extra-scripts.sh"

exec /promknight-entrypoint.sh
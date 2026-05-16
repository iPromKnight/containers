#!/usr/bin/env bash
AUTH="Authorization: token ${GH_PAT:-${TOKEN:-}}"
version=$(curl -sLf -H "$AUTH" https://api.github.com/repos/iPromKnight/proton-gluetun-updater/releases/latest | jq --raw-output '. | .tag_name')
printf "%s" "${version}"

#!/usr/bin/env bash
AUTH="Authorization: token ${GH_PAT:-${TOKEN:-}}"
version=$(curl -Lsf -H "$AUTH" https://api.github.com/repos/rclone/rclone/releases/latest | jq --raw-output '. | .tag_name')
version="${version#*v}"
printf "%s" "${version}"

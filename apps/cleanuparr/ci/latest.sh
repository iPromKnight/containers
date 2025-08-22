#!/usr/bin/env bash
AUTH="Authorization: token ${GH_PAT:-${TOKEN:-}}"
version=$(curl -sLf -H "$AUTH" https://api.github.com/repos/Cleanuparr/Cleanuparr/releases/latest | jq --raw-output '. | .tag_name')
version="${version#*v}"
printf "%s" "${version}"
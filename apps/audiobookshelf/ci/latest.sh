#!/usr/bin/env bash
AUTH="Authorization: token ${GH_PAT:-${TOKEN:-}}"
version=$(curl -sLf -H "$AUTH" https://api.github.com/repos/advplyr/audiobookshelf/releases/latest | jq --raw-output '. | .tag_name')
# version="${version#*v}"
version="${version#*release-}"
printf "%s" "${version}"

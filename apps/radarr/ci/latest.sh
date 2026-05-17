#!/usr/bin/env bash
channel=$1
version=$(curl -sfL "https://api.github.com/repos/realzombee/Radarr/releases?per_page=1" | jq --raw-output '.[0].tag_name' 2>/dev/null)
version="${version#v}"
version="${version#release-}"
printf "%s" "${version}"
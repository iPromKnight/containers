#!/usr/bin/env bash
channel=$1
version=$(curl -sLf "https://api.github.com/repos/realzombee/Prowlarr/releases?per_page=1" | jq --raw-output '.[0].tag_name')
version="${version#v}"
version="${version#release-}"
printf "%s" "${version}"

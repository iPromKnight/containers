#!/usr/bin/env bash
version=$(curl -sLf "https://api.github.com/repos/Tautulli/Tautulli/releases/latest" | jq --raw-output '. | .tag_name')
version="${version#*v}"
version="${version#*release-}"
printf "%s" "${version}"

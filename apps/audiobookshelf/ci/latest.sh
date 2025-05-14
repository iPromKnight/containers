#!/usr/bin/env bash
version=$(curl -sLf https://api.github.com/repos/advplyr/audiobookshelf/releases/latest | jq --raw-output '. | .tag_name')
# version="${version#*v}"
version="${version#*release-}"
printf "%s" "${version}"

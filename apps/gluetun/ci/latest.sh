#!/usr/bin/env bash
version=$(curl -L https://api.github.com/repos/qdm12/gluetun/releases/latest | jq --raw-output '. | .tag_name')
version="${version#*v}"
printf "%s" "${version}"

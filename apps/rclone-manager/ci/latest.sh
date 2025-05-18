#!/usr/bin/env bash
version=$(curl -Lsf https://api.github.com/repos/rclone/rclone/releases/latest | jq --raw-output '. | .tag_name')
version="${version#*v}"
printf "%s" "${version}"

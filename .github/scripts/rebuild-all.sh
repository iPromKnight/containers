#!/usr/bin/env bash

shopt -s lastpipe

[[ -n "${DEBUG:-}" ]] && set -x

declare -a changes_array

while read -r metadata; do
  if [[ ! -f "$metadata" ]]; then
    echo "⚠️ Skipping invalid file: $metadata"
    continue
  fi
  
  if jq -e '.base == true' "$metadata" > /dev/null; then
    app="$(jq --raw-output '.app' "$metadata")"
    echo "⏭️ Skipping base image app: ${app}"
    continue
  fi

  app="$(jq --raw-output '.app' "$metadata")"
  
  echo "🔍 Collecting app: ${app}"

  while read -r channel_info; do
    channel="$(jq --raw-output '.name' <<< "$channel_info")"
    changes_array+=("$(jo app="$app" channel="$channel")")
  done < <(jq --raw-output -c '.channels | .[]' "$metadata")
done < <(find ./apps -name metadata.json)

output="$(jo -a "${changes_array[@]}")"

echo "✅ Manual rebuild forced. Including all apps/channels:"
echo "$output"
echo "changes=${output}" >> "$GITHUB_OUTPUT"

image_list="$(printf '%s\n' "${changes_array[@]}" \
  | jq -R -s -c 'split("\n") | map(select(length > 0)) | map(fromjson | "\(.app):\(.channel)")')"

echo "images=${image_list}" >> "$GITHUB_OUTPUT"
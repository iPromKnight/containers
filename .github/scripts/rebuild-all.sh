#!/usr/bin/env bash

shopt -s lastpipe

[[ -n "${DEBUG:-}" ]] && set -x

declare -a merge_array  # one entry per (app, channel) — used by merge job
declare -a build_array  # one entry per (app, channel, platform) — used by build matrix

# Map docker-style platform (linux/amd64) to GitHub Actions runner label.
# Falls back to ubuntu-latest for anything we don't explicitly know.
runner_for_platform() {
  case "$1" in
    linux/amd64) echo "ubuntu-24.04" ;;
    linux/arm64) echo "ubuntu-24.04-arm" ;;
    *)           echo "ubuntu-latest" ;;
  esac
}

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
    merge_array+=("$(jo app="$app" channel="$channel")")

    while read -r platform; do
      runner="$(runner_for_platform "$platform")"
      build_array+=("$(jo app="$app" channel="$channel" platform="$platform" runner="$runner")")
    done < <(jq --raw-output '.platforms | .[]' <<< "$channel_info")
  done < <(jq --raw-output -c '.channels | .[]' "$metadata")
done < <(find ./apps -name metadata.json)

merge_output="$(jo -a "${merge_array[@]}")"
build_output="$(jo -a "${build_array[@]}")"

echo "✅ Manual rebuild forced."
echo "Merge matrix (one entry per app/channel, ${#merge_array[@]} entries):"
echo "$merge_output"
echo "Build matrix (one entry per app/channel/platform, ${#build_array[@]} entries):"
echo "$build_output"

echo "changes=${merge_output}"      >> "$GITHUB_OUTPUT"
echo "build_matrix=${build_output}" >> "$GITHUB_OUTPUT"

image_list="$(printf '%s\n' "${merge_array[@]}" \
  | jq -R -s -c 'split("\n") | map(select(length > 0)) | map(fromjson | "\(.app):\(.channel)")')"

echo "images=${image_list}" >> "$GITHUB_OUTPUT"

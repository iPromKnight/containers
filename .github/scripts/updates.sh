#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

[[ -n "${DEBUG:-}" ]] && set -x

declare -A app_channel_array
app_channel_array[_initialized]=""

# Per-channel platform list, keyed by "$app:$channel" → space-separated platforms.
# Populated in process_channel as we visit each channel of each metadata.json.
declare -A channel_platforms

declare -a merge_array  # one entry per (app, channel) — used by merge job
declare -a build_array  # one entry per (app, channel, platform) — used by build matrix

runner_for_platform() {
  case "$1" in
    linux/amd64) echo "ubuntu-24.04" ;;
    linux/arm64) echo "ubuntu-24.04-arm" ;;
    *)           echo "ubuntu-latest" ;;
  esac
}

process_channel() {
  local app="$1"
  local channel="$2"
  local stable="$3"
  local platforms_str="$4"  # space-separated, e.g. "linux/amd64 linux/arm64"

  echo "::group::Checking ${app}/${channel} (stable=${stable})"

  published_version=$(
    ./.github/scripts/published.sh "${app}" "${channel}" "${stable}" || {
      echo "❌ published.sh failed for ${app}/${channel}" >&2
      echo "::endgroup::"
      return 1
    }
  )

  upstream_version=$(
    ./.github/scripts/upstream.sh "${app}" "${channel}" "${stable}" || {
      echo "❌ upstream.sh failed for ${app}/${channel}" >&2
      echo "::endgroup::"
      return 1
    }
  )

  echo "📦 ${app}/${channel}: published=${published_version:-<NOTFOUND>}, upstream=${upstream_version:-<NOTFOUND>}"

  if [[ "${published_version}" != "${upstream_version}" ]]; then
    echo "🔄 Update required: ${app}$([[ ! ${stable} == false ]] || echo "-${channel}") -> ${upstream_version}"
    # Stash the platform list keyed by app:channel so emit_output can use it.
    channel_platforms["${app}:${channel}"]="${platforms_str}"
    echo "${channel}" >&3
  fi

  echo "::endgroup::"
}

process_metadata_file() {
  local metadata="$1"

  if [[ ! -f "$metadata" ]]; then
    echo "⚠️ Skipping invalid file: $metadata"
    return
  fi

  local app
  app="$(jq --raw-output '.app' "$metadata")"
  echo "🔍 Processing app: ${app}"

  local channel_info
  local -a updated_channels=()

  while read -r channel_info; do
    local channel stable platforms_str
    channel="$(jq --raw-output '.name' <<< "$channel_info")"
    stable="$(jq --raw-output '.stable' <<< "$channel_info")"
    platforms_str="$(jq --raw-output '.platforms | join(" ")' <<< "$channel_info")"

    # Capture only the return value from FD 3
    if updated_channel="$(process_channel "$app" "$channel" "$stable" "$platforms_str" 3>&1 1>&2)"; then
      [[ -n "$updated_channel" ]] && updated_channels+=("$updated_channel")
    fi
  done < <(jq --raw-output -c '.channels | .[]' "$metadata")

  if [[ "${#updated_channels[@]}" -gt 0 ]]; then
    app_channel_array["$app"]="${updated_channels[*]}"
  fi
}

emit_output() {
  local merge_output="[]"
  local build_output="[]"

  if (( ${#app_channel_array[@]} > 1 )); then  # 1 = only _initialized
    unset 'app_channel_array[_initialized]'
    for app in "${!app_channel_array[@]}"; do
      for channel in ${app_channel_array[$app]}; do
        merge_array+=("$(jo app="$app" channel="$channel")")
        for platform in ${channel_platforms["${app}:${channel}"]}; do
          runner="$(runner_for_platform "$platform")"
          build_array+=("$(jo app="$app" channel="$channel" platform="$platform" runner="$runner")")
        done
      done
    done
    merge_output="$(jo -a "${merge_array[@]}")"
    build_output="$(jo -a "${build_array[@]}")"
  fi

  if [[ "$merge_output" == "[]" ]]; then
    echo "✅ No changes detected."
    echo "changes=[]"      >> "$GITHUB_OUTPUT"
    echo "build_matrix=[]" >> "$GITHUB_OUTPUT"
    echo "images=[]"       >> "$GITHUB_OUTPUT"
    echo "⏭️ Skipping build. Nothing to do..."
    exit 0
  else
    echo "✅ Changes detected:"
    echo "Merge matrix (${#merge_array[@]} entries):"
    echo "$merge_output"
    echo "Build matrix (${#build_array[@]} entries):"
    echo "$build_output"
    echo "changes=${merge_output}"      >> "$GITHUB_OUTPUT"
    echo "build_matrix=${build_output}" >> "$GITHUB_OUTPUT"
  fi

  local image_list="[]"
  if [[ "${#merge_array[@]}" -gt 0 ]]; then
    image_list="$(printf '%s\n' "${merge_array[@]}" \
      | jq -R -s -c 'split("\n") | map(select(length > 0)) | map(fromjson | "\(.app):\(.channel)")')"
  fi

  echo "images=${image_list}" >> "$GITHUB_OUTPUT"
}

main() {
  while read -r metadata; do
    process_metadata_file "$metadata"
  done < <(find ./apps -name metadata.json)

  emit_output
}

main "$@"

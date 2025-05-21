#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

[[ -n "${DEBUG:-}" ]] && set -x

declare -A app_channel_array
app_channel_array[_initialized]=""

declare -a changes_array

process_channel() {
  local app="$1"
  local channel="$2"
  local stable="$3"

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
    local channel stable
    channel="$(jq --raw-output '.name' <<< "$channel_info")"
    stable="$(jq --raw-output '.stable' <<< "$channel_info")"

    # Capture only the return value from FD 3
    if updated_channel="$(process_channel "$app" "$channel" "$stable" 3>&1 1>&2)"; then
      [[ -n "$updated_channel" ]] && updated_channels+=("$updated_channel")
    fi
  done < <(jq --raw-output -c '.channels | .[]' "$metadata")

  if [[ "${#updated_channels[@]}" -gt 0 ]]; then
    app_channel_array["$app"]="${updated_channels[*]}"
  fi
}

emit_output() {
  local output="[]"

  if (( ${#app_channel_array[@]} > 1 )); then  # 1 = only _initialized
    unset 'app_channel_array[_initialized]'
    for app in "${!app_channel_array[@]}"; do
      for channel in ${app_channel_array[$app]}; do
        changes_array+=("$(jo app="$app" channel="$channel")")
      done
    done
    output="$(jo -a "${changes_array[@]}")"
  fi

  if [[ "$output" == "[]" ]]; then
    echo "✅ No changes detected."
    echo "changes=[]" >> "$GITHUB_OUTPUT"
    echo "images=[]" >> "$GITHUB_OUTPUT"
    echo "⏭️ Skipping build. Nothing to do..."
    exit 0
  else
    echo "✅ Changes detected:"
    echo "$output"
    echo "changes=${output}" >> "$GITHUB_OUTPUT"
  fi

  local image_list="[]"
  if [[ "${#changes_array[@]}" -gt 0 ]]; then
    image_list="$(printf '%s\n' "${changes_array[@]}" \
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
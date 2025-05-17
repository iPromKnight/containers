#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

[[ -n "${DEBUG:-}" ]] && set -x

declare -A app_channel_array

find ./apps -name metadata.json | while read -r metadata; do
    if [[ ! -f "$metadata" ]]; then
        echo "⚠️ Skipping invalid file: $metadata"
        continue
    fi

    app="$(jq --raw-output '.app' "${metadata}")"
    echo "🔍 Processing app: ${app}"

    declare -a __channels=()
    jq --raw-output -c '.channels | .[]' "${metadata}" | while read -r channels; do
        channel="$(jq --raw-output '.name' <<< "${channels}")"
        stable="$(jq --raw-output '.stable' <<< "${channels}")"

        echo "::group::Checking ${app}/${channel} (stable=${stable})"
        
        published_version=$(
            ./.github/scripts/published.sh "${app}" "${channel}" "${stable}" || {
                echo "❌ published.sh failed for ${app}/${channel}" >&2
                continue
            }
        )

        upstream_version=$(
            ./.github/scripts/upstream.sh "${app}" "${channel}" "${stable}" || {
                echo "❌ upstream.sh failed for ${app}/${channel}" >&2
                continue
            }
        )

        echo "📦 ${app}/${channel}: published=${published_version:-<NOTFOUND>}, upstream=${upstream_version:-<NOTFOUND>}"

        if [[ "${published_version}" != "${upstream_version}" ]]; then
            echo "🔄 Update required: ${app}$([[ ! ${stable} == false ]] || echo "-${channel}") -> ${upstream_version}"
            __channels+=("${channel}")
        fi

        echo "::endgroup::"
    done

    if [[ "${#__channels[@]}" -gt 0 ]]; then
        app_channel_array[$app]="${__channels[*]}"
    fi
done

output="[]"
if [[ "${#app_channel_array[@]}" -gt 0 ]]; then
    declare -a changes_array=()
    for app in "${!app_channel_array[@]}"; do
        for channel in ${app_channel_array[$app]}; do
            changes_array+=("$(jo app="$app" channel="$channel")")
        done
    done
    output="$(jo -a ${changes_array[*]})"
fi

if [[ "$output" == "[]" ]]; then
    echo "✅ No changes detected."
else
    echo "✅ Changes detected:"
    echo "$output"
fi

echo "changes=${output}" >> "$GITHUB_OUTPUT"

image_list="[]"
if [[ "${#changes_array[@]}" -gt 0 ]]; then
  image_list="$(printf '%s\n' "${changes_array[@]}" \
    | jq -R -s -c 'split("\n") | map(select(length > 0)) | map(fromjson | "\(.app):\(.channel)")')"
fi

echo "images=${image_list}" >> "$GITHUB_OUTPUT"
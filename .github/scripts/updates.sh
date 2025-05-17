#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

declare -A app_channel_array
find ./apps -name metadata.json | while read -r metadata; do
    declare -a __channels=()
    app="$(jq --raw-output '.app' "${metadata}")"
    jq --raw-output -c '.channels | .[]' "${metadata}" | while read -r channels; do
        channel="$(jq --raw-output '.name' <<< "${channels}")"
        stable="$(jq --raw-output '.stable' <<< "${channels}")"
        published_version=$(./.github/scripts/published.sh "${app}" "${channel}" "${stable}")
        upstream_version=$(./.github/scripts/upstream.sh "${app}" "${channel}" "${stable}")
        if [[ "${published_version}" != "${upstream_version}" ]]; then
            echo "${app}$([[ ! ${stable} == false ]] || echo "-${channel}"):${published_version:-<NOTFOUND>} -> ${upstream_version}"
            __channels+=("${channel}")
        fi
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

echo "changes=${output}" >> "$GITHUB_OUTPUT"
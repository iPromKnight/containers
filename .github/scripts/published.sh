#!/usr/bin/env bash
set -euo pipefail

APP="$1"
CHANNEL="$2"
STABLE="${3:-false}"

# Build image name if channel is not stable
if [[ "${STABLE}" == "false" || -z "${STABLE}" ]]; then
  APP="${APP}-${CHANNEL}"
fi

# Use either GH_PAT or TOKEN
AUTH="Authorization: Bearer ${GH_PAT:-${TOKEN:-}}"

# Query GitHub Packages API
tags_json=$(curl -fsSL -H "Accept: application/vnd.github.v3+json" -H "$AUTH" \
  "https://api.github.com/ipromknight/packages/container/${APP}/versions")

# If the API call failed or returned nothing
if [[ -z "${tags_json}" || "${tags_json}" == "[]" ]]; then
  exit 0
fi

# Get all tags except 'rolling'
tag=$(jq -r '
  map(.metadata.container.tags[]) | 
  map(select(. != "rolling")) |
  .[0] // empty
' <<< "$tags_json")

[[ -n "$tag" ]] && echo "$tag"
#!/usr/bin/env bash
# Track the HEAD of upstream main so the update check sees a new "version"
# whenever main moves forward. The `dev` tag is unreliable — it's force-pushed
# sporadically and has lagged main by weeks in the past.
AUTH="Authorization: token ${GH_PAT:-${TOKEN:-}}"
sha=$(curl -sLf -H "$AUTH" https://api.github.com/repos/javi11/altmount/commits/main | jq --raw-output '.sha')
printf "main-%s" "${sha:0:7}"

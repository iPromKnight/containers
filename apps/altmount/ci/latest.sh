#!/usr/bin/env bash
# Track the HEAD of the channel's source branch so the update check sees a new
# "version" whenever it moves forward.
#
# - main channel: upstream javi11/altmount@main (the `dev` tag is unreliable —
#   it's force-pushed sporadically and has lagged main by weeks in the past).
# - dev channel:  fork iPromKnight/altmount@feat/connection_handling — locally
#   carried streaming/connection-handling work-in-progress.
AUTH="Authorization: token ${GH_PAT:-${TOKEN:-}}"
CHANNEL="${1:-main}"

case "$CHANNEL" in
    dev)
        REPO="iPromKnight/altmount"
        BRANCH="feat/connection_handling"
        ;;
    *)
        REPO="javi11/altmount"
        BRANCH="main"
        ;;
esac

sha=$(curl -sLf -H "$AUTH" "https://api.github.com/repos/${REPO}/commits/${BRANCH}" | jq --raw-output '.sha')
printf "%s-%s" "$CHANNEL" "${sha:0:7}"

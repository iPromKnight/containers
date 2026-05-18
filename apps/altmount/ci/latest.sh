#!/usr/bin/env bash
AUTH="Authorization: token ${GH_PAT:-${TOKEN:-}}"
CHANNEL="${1:-main}"

case "$CHANNEL" in
    dev)
        REPO="iPromKnight/altmount"
        BRANCH="dev"
        ;;
    *)
        REPO="javi11/altmount"
        BRANCH="main"
        ;;
esac

sha=$(curl -sLf -H "$AUTH" "https://api.github.com/repos/${REPO}/commits/${BRANCH}" | jq --raw-output '.sha')
printf "%s-%s" "$CHANNEL" "${sha:0:7}"

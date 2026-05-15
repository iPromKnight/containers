#!/usr/bin/env bash
# altmount publishes a rolling `dev` tag that gets force-pushed.
# Resolve the tag to the commit SHA it currently points to so the update
# check sees a new "version" whenever upstream moves the tag.
AUTH="Authorization: token ${GH_PAT:-${TOKEN:-}}"
sha=$(curl -sLf -H "$AUTH" https://api.github.com/repos/javi11/altmount/git/refs/tags/dev | jq --raw-output '.object.sha')
printf "dev-%s" "${sha:0:7}"

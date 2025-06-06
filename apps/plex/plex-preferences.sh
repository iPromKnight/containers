#!/usr/bin/env bash

umask "${UMASK}"

mask() {
    local n=3
    [[ ${#1} -le 5 ]] && n=$(( ${#1} - 3 ))
    local a="${1:0:${#1}-n}"
    local b="${1:${#1}-n}"
    printf "%s%s\n" "${a//?/*}" "$b"
}

echo "
----------------------------------------------------------------------
ENVIRONMENT APP
----------------------------------------------------------------------
WEBUI_PORTS=${WEBUI_PORTS}
PLEX_CLAIM_TOKEN=$(mask "${PLEX_CLAIM_TOKEN}")
PLEX_ADVERTISE_URL=${PLEX_ADVERTISE_URL}
PLEX_NO_AUTH_NETWORKS=${PLEX_NO_AUTH_NETWORKS}
PLEX_PURGE_CODECS=${PLEX_PURGE_CODECS}
PLEX_HW_SUPPORT=${PLEX_HW_SUPPORT}
CONFIG_DIR=${CONFIG_DIR}
----------------------------------------------------------------------
"

############
## Functions
function getPref {
    local key="$1"
    xmlstarlet sel -T -t -m "/Preferences" -v "@${key}" -n "${prefFile}"
}

function setPref {
    local key="$1"
    local value="$2"
    count="$(xmlstarlet sel -t -v "count(/Preferences/@${key})" "${prefFile}")"
    count=$((count + 0))
    if [[ $count -gt 0 ]]; then
        xmlstarlet ed --inplace --update "/Preferences/@${key}" -v "${value}" "${prefFile}"
    else
        xmlstarlet ed --inplace --insert "/Preferences"  --type attr -n "${key}" -v "${value}" "${prefFile}"
    fi
}

#################
## Configure Plex
mkdir -p "${CONFIG_DIR}" || exit 1
prefFile="${CONFIG_DIR}/Preferences.xml"

# Create empty Preferences.xml file if it doesn't exist already
if [[ ! -f "${prefFile}" ]]; then
    echo "Creating empty Preferences.xml..."
    cat > "${prefFile}" <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<Preferences/>
EOF
fi

# Setup Server's client identifier
serial="$(getPref "MachineIdentifier")"
if [[ -z "${serial}" ]]; then
    serial="$(cat /proc/sys/kernel/random/uuid)"
    setPref "MachineIdentifier" "${serial}"
fi
clientId="$(getPref "ProcessedMachineIdentifier")"
if [[ -z "${clientId}" ]]; then
    clientId="$(echo -n "${serial}- Plex Media Server" | sha1sum | cut -b 1-40)"
    setPref "ProcessedMachineIdentifier" "${clientId}"
fi

# Get server token and only turn claim token into server token if we have former but not latter.
token="$(getPref "PlexOnlineToken")"
if [[ -n "${PLEX_CLAIM_TOKEN}" ]] && [[ -z "${token}" ]]; then
    echo "Attempting to obtain server token from claim token..."
    loginInfo="$(curl -fsSL -X POST \
        -H 'X-Plex-Client-Identifier: '"${clientId}" \
        -H 'X-Plex-Product: Plex Media Server'\
        -H 'X-Plex-Version: 1.1' \
        -H 'X-Plex-Provides: server' \
        -H 'X-Plex-Platform: Linux' \
        -H 'X-Plex-Platform-Version: 1.0' \
        -H 'X-Plex-Device-Name: PlexMediaServer' \
        -H 'X-Plex-Device: Linux' \
        "https://plex.tv/api/claim/exchange?token=${PLEX_CLAIM_TOKEN}")"
    token="$(echo "$loginInfo" | sed -n 's/.*<authentication-token>\(.*\)<\/authentication-token>.*/\1/p')"

    if [[ "$token" ]]; then
        echo "Token obtained successfully!"
        setPref "PlexOnlineToken" "${token}"
    fi
fi

# Set other preferences
[[ -n "${ADVERTISE_IP}" ]] && PLEX_ADVERTISE_URL=${ADVERTISE_IP}
if [[ -n "${PLEX_ADVERTISE_URL}" ]]; then
    echo "Setting customConnections to: ${PLEX_ADVERTISE_URL}"
    setPref "customConnections" "${PLEX_ADVERTISE_URL}"
fi

[[ -n "${ALLOWED_NETWORKS}" ]] && PLEX_NO_AUTH_NETWORKS=${ALLOWED_NETWORKS}
if [[ -n "${PLEX_NO_AUTH_NETWORKS}" ]]; then
    echo "Setting allowedNetworks to: ${PLEX_NO_AUTH_NETWORKS}"
    setPref "allowedNetworks" "${PLEX_NO_AUTH_NETWORKS}"
fi

# Set transcoder directory if not yet set
if [[ -z "$(getPref "TranscoderTempDirectory")" ]]; then
    echo "Setting TranscoderTempDirectory to: /transcode"
    setPref "TranscoderTempDirectory" "/transcode"
fi

# Remove pid file
rm -f "${CONFIG_DIR}/plexmediaserver.pid" || true

#############
## HW Support
if [[ "${PLEX_HW_SUPPORT}" == "true" ]]; then
DEVICES=$(find /dev/dri /dev/dvb -type c -print 2>/dev/null)

for i in ${DEVICES}; do
    # Get the group ID and NAME (if exists) for the current device in the list
    DEVICE_GROUP_ID=$(stat -c '%g' "$i")
    DEVICE_GROUP_NAME=$(getent group "${DEVICE_GROUP_ID}" | awk -F: '{print $1}')

    # If group NAME doesn't exist, create it and assign it the group ID
    if [[ -z "${DEVICE_GROUP_NAME}" ]]; then
        DEVICE_GROUP_NAME="video${RANDOM}"
        groupadd -g "${DEVICE_GROUP_ID}" "${DEVICE_GROUP_NAME}"
    fi

    getent group "${DEVICE_GROUP_NAME}" | grep -q 568 || usermod -a -G "${DEVICE_GROUP_NAME}" 568
done
fi

######################
## Purge Codecs folder
if [[ "${PLEX_PURGE_CODECS}" == "true" ]]; then
    echo "Purging Codecs folder..."
    find "${CONFIG_DIR}/Codecs" -mindepth 1 -not -name '.device-id' -print -delete
fi
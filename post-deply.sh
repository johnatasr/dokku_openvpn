#!/usr/bin/env bash
set -eo pipefail; [[ $DOKKU_TRACE ]] && set -x
source "$PLUGIN_CORE_AVAILABLE_PATH/common/functions"
source "$PLUGIN_CORE_AVAILABLE_PATH/config/functions"

dokku_log_verbose "Running openvpn-client"

APP="$1"
verify_app_name "$APP"
CONFIGURE_OPENVPN=$(config_get "${APP}" "CONFIGURE_OPENVPN_CLIENT") || true

if [ ! -z "${CONFIGURE_OPENVPN}" ] ; then
    CONTAINER_IDS=$( \
        docker ps \
        --filter ancestor="dokku/${APP}:latest" \
        --filter name="web" \
        -q \
    )
    CONFIGURE_COMMAND=""
    CONFIGURE_COMMAND+='for path in /app/openvpn-* ; do'
    CONFIGURE_COMMAND+='  target_file=${path#/app/openvpn-} ; '
    CONFIGURE_COMMAND+='  target_path=/etc/openvpn/${target_file} ; '
    CONFIGURE_COMMAND+='  echo "- Installing ${path} to ${target_path}" ; '
    CONFIGURE_COMMAND+='  cp ${path} ${target_path} ; '
    CONFIGURE_COMMAND+='done ; '

    for id in "${CONTAINER_IDS}" ; do
        dokku_log_verbose "Configuring openvpn client in container ${id}"
        docker exec \
            --user root \
            --privileged \
            "${id}" \
            bash -c "${CONFIGURE_COMMAND}"

        docker exec \
            --user root \
            --privileged \
            "${id}" \
            bash -c 'mkdir /dev/net ; mknod /dev/net/tun c 10 200;'

        docker exec \
            --user root \
            --privileged \
            "${id}" \
            bash -c 'openvpn --config /etc/openvpn/client-pfSense-UDP4-1194.ovpn'
    done
fi
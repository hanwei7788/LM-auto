#!/bin/bash
#
# Restarts ui_center on target
# Params: ip [port]
#

TARGET_IP=$1
TARGET_PORT=$2

# if target port has not been defined, then use default
if [[ -z ${TARGET_PORT} ]]; then
  TARGET_PORT=22
fi

ssh -p ${TARGET_PORT} system@${TARGET_IP} "systemctl --user restart skytree-compositor.service"


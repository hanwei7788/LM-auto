#!/bin/bash
#########################################################
#
# A helper script for listing the journal on the device
#
# Authors: Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#
# License: Proprietary
# (C) 2016 Link Motion Oy
# All Rights reserved
#########################################################

function exit_on_failure() {
  set -e
}
function dont_exit_on_failure() {
  set +e
}
exit_on_failure

function usage() {
	echo
	echo "USAGE: ./device-show-journal.sh [target-ip] [target-port (optional)]"
	echo
}

###
# Arguments
TARGET_IP=$1
TARGET_PORT=$2

###
# check that the target ip was given
if [[ -z ${TARGET_IP} ]]; then
	usage
	echo "ERROR: Target ip was not set"
	exit 1
fi

###
# if target port has not been defined, then use default
if [[ -z ${TARGET_PORT} ]]; then
  TARGET_PORT=22
fi

###
# show journal
ssh -p ${TARGET_PORT} root@${TARGET_IP} journalctl
#!/bin/bash
#########################################################
#
# A helper script for execute zypper on device
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
	echo "USAGE: ./device-zypper.sh [target_ip] [target_port] [args]"
	echo
}

TARGET_IP=$1
TARGET_PORT=$2
ZYPPER_ARGS=${@:3}

###
# check that the target ip was given
if [[ -z ${TARGET_IP} ]]; then
	usage
	echo "ERROR: Target ip was not set"
	exit 1
fi

###
# check that the target ip was given
if [[ -z ${TARGET_PORT} ]]; then
	usage
	echo "ERROR: Target port was not set"
	exit 1
fi


###
# Execute zypper on device
ssh -p ${TARGET_PORT} root@${TARGET_IP} zypper ${ZYPPER_ARGS}

#!/bin/bash
#########################################################
#
# A helper script for installing package into device
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
	echo "USAGE: ./device-install-rpm.sh [rpm-filename] [target-ip] [target-port (optional)]"
	echo
}

###
# Arguments
RPM_FILENAME=$1
TARGET_IP=$2
TARGET_PORT=$3
TEMPORARY_PATH=dev-upload

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
# if user did not give us the RPM filename then show the usage.
if [[ -z ${RPM_FILENAME} ]]; then
	usage
	exit 1
fi

###
# if user gave an invalid path to the RPM file, show usage and an error message.
if [[ ! -f ${RPM_FILENAME} ]]; then
	usage
	echo "ERROR: RPM file does not exists. (${RPM_FILENAME})"
	exit 2
fi

###
# Create a temporary path, if it does not exist
ssh -p ${TARGET_PORT} root@${TARGET_IP} mkdir -p /tmp/${TEMPORARY_PATH}

###
# Make sure that it is empty
ssh -p ${TARGET_PORT} root@${TARGET_IP} rm -rf /tmp/${TEMPORARY_PATH}/*

###
# Transfer the RPM file to remote address
scp -P ${TARGET_PORT} ${RPM_FILENAME} root@${TARGET_IP}:/tmp/${TEMPORARY_PATH}

###
# Install the package inside the remote machine from temporary location
ssh -p ${TARGET_PORT} root@${TARGET_IP} rpm -ivh --force --ignorearch /tmp/${TEMPORARY_PATH}/*.rpm
#ssh -p ${TARGET_PORT} root@${TARGET_IP} zypper --non-interactive --no-gpg-check in -f /tmp/${TEMPORARY_PATH}/*.rpm


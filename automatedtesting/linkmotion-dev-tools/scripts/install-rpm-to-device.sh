#!/bin/bash
#
# Install a single rpm file to a lm device's ivios.
#
# Usage:
# ./install-rpm-to-device.sh <rpm> <device ip>
#
# Example:
#
# ./linkmotion-dev-tools/scripts/install-rpm-to-device.sh ~/Downloads/lmmw-ivi-entertain-plugin-1.0.71-1.armv7tnhl.rpm lmhw
#
# TODO: Support for autoos


# set work path to scriptpath
SCRIPTFILE=`realpath $0`
SCRIPTPATH=`dirname ${SCRIPTFILE}`
pushd ${SCRIPTPATH} > /dev/null
source ../scripts/common-functions.sh

RPM_FILE=$1
TARGET_IP=$2

ssh root@${TARGET_IP} lxc-attach -P /usr/lib/lm_containers -n ivi -- rm -fr "/root/install" || true
ssh root@${TARGET_IP} lxc-attach -P /usr/lib/lm_containers -n ivi -- mkdir -p "/root/install"
scp $1 root@${TARGET_IP}:${IVIROOTFS}/root/install
ssh root@${TARGET_IP} lxc-attach -P /usr/lib/lm_containers -n ivi -- rpm -ivh --force --ignorearch "/root/install/*.rpm"
ssh root@${TARGET_IP} lxc-attach -P /usr/lib/lm_containers -n ivi -- rm -fr "/root/install"


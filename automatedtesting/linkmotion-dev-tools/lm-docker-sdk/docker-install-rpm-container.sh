#!/bin/bash

#
# Builds RPM package and installs it to a container.
#
# This script is WIP, don't use yet.
#
# Usage: docker-install-rpm-container.sh <package> <target ip>
#

TARGET_IP=$2

# set work path to scriptpath
SCRIPTFILE=`realpath $0`
SCRIPTPATH=`dirname ${SCRIPTFILE}`
pushd ${SCRIPTPATH} > /dev/null
source ../scripts/common-functions.sh

set_src_dir

cd ${SRC_DIR}

${SCRIPTPATH}/docker-build.sh $1
echo
echo "Packages built - copying to target:"
ssh root@${TARGET_IP} lxc-attach -P /usr/lib/lm_containers -n ivi -- rm -fr "/root/install" || true
ssh root@${TARGET_IP} lxc-attach -P /usr/lib/lm_containers -n ivi -- mkdir -p "/root/install"
scp build-$1-imx6/*.rpm root@${TARGET_IP}:${IVIROOTFS}/root/install
echo
echo "Installing packages:"
ssh root@${TARGET_IP} lxc-attach -P /usr/lib/lm_containers -n ivi -- rpm -ivh --force --ignorearch "/root/install/*.rpm"
ssh root@${TARGET_IP} lxc-attach -P /usr/lib/lm_containers -n ivi -- rm -fr "/root/install"
echo 
echo "Packages installed on target."
echo


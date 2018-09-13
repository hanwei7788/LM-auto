#!/bin/bash
#########################################################
#
# Sets up new LM Device or VM for development.
#
# Authors: Ville Ranki <ville.ranki@nomovok.com>
#          Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
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

# set work path to scriptpath
SCRIPTFILE=`realpath $0`
SCRIPTPATH=`dirname ${SCRIPTFILE}`
pushd ${SCRIPTPATH} > /dev/null

function usage() {
	echo
	echo "USAGE: ./setup-new-device.sh <target-ip> [target-port]"
	echo
}

TARGET_IP=$1
TARGET_PORT=$2

if [ -n "${TARGET_IP}" ]; then
    echo "Target ip ${TARGET_IP}"
else
	usage
    echo "ERROR: Please provide target ip as parameter"
    exit 1
fi

if [ -n "${TARGET_PORT}" ]; then
    echo "Target port ${TARGET_PORT}"
else
	TARGET_PORT=22
fi



if ping -c 1 ${TARGET_IP} &> /dev/null
then
  echo "${TARGET_IP} is up, continuing.."
else
  echo "${TARGET_IP} is not reachable. Check ip and device."
  exit 1
fi

echo "Cleaning up old ssh keys.."
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R ${TARGET_IP}
# If target ip really is given as hostname, clean up also the ip.
REAL_IP=`getent hosts lmhw | awk '{ print $1 }'`
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R ${REAL_IP}

echo
echo "Setting up ${TARGET_IP}"
echo
echo " - passwordless login"
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R ${TARGET_IP}:${TARGET_PORT}
sshpass -p 'skytree' ssh-copy-id -o "StrictHostKeyChecking no" -p ${TARGET_PORT} root@${TARGET_IP}
sshpass -p 'skytree' ssh-copy-id -o "StrictHostKeyChecking no" -p ${TARGET_PORT} system@${TARGET_IP}
echo " - journald logging"
scp -P ${TARGET_PORT}  setup_files/journald.conf root@${TARGET_IP}:/etc/systemd/journald.conf
echo " - ivios networking scripts (to /root in autoos)"
scp -P ${TARGET_PORT}  setup_files/*-networking.sh root@${TARGET_IP}:/root
echo " - system update script (to /root in autoos)"
scp -P ${TARGET_PORT}  setup_files/update.sh root@${TARGET_IP}:/root
echo
echo "..setup complete!"

echo
read -p "Would you like to install test data on the device? [y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	$SCRIPTPATH/install_test_data.sh ${TARGET_IP} ${TARGET_PORT}
fi

echo "Rebooting..."
ssh -o ServerAliveInterval=1 -p ${TARGET_PORT} root@${TARGET_IP} reboot
echo "Device ${TARGET_IP} set up. Commands to copypaste: [ ssh -p ${TARGET_PORT} root@${TARGET_IP} ]   [ ssh -p ${TARGET_PORT} system@${TARGET_IP} ]"
echo

popd

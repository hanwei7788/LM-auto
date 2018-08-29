#!/bin/bash
#
# This script is WIP, don't use yet. -VR
#
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

ssh-keygen -f "/home/vranki/.ssh/known_hosts" -R $TARGET_IP
sshpass -p 'skytree' ssh-copy-id -o "StrictHostKeyChecking no" -p ${TARGET_PORT} root@${TARGET_IP}


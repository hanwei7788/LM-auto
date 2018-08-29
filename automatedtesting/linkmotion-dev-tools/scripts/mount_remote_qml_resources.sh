#!/bin/bash
#
# This script mounts the qml resources directory on remote hardware
# to edit locally. It also configures the qmlpath variable in ui_center
# to load the files in filesystem, not in resources.
#
# Usage:
#
# mount_remote_qml_resources.sh <ip address>
#
# Pre-requisites:
#
# - Hardware set up and accessible via ssh (see setup_new_device.sh)
# - ui_center-resources package installed in ivios side. (see docker-install-rpm-container.sh)
# - /etc/fuse.conf user_allow_other option enabled on host
#
# To un-mount, run fusermount -u /tmp/ui_center-qml
#
# You'll need to re-run this if you install the ui_center rpm, as it will
# reinstall default.ini config.
#

TARGET_IP=$1
MOUNT_POINT=/tmp/ui_center-qml

if [ -z ${TARGET_IP} ]; then
    echo "error: Target ip not set. Set it as parameter."
    exit -1
fi

echo
mkdir -p ${MOUNT_POINT} || true
echo "Changing qmlpath= option in default.ini to use the ui_center resources.."
ssh root@${TARGET_IP} sed -i '/qmlpath=/c\qmlpath=\/usr\/apps\/org.c4c.ui_center/qml' /altdata/lxc/ivi/rootfs/altdata/system/ui/center-configurations/default.ini
echo "Mounting the resources path.."
sshfs root@${TARGET_IP}:/altdata/lxc/ivi/rootfs/usr/apps/org.c4c.ui_center /tmp/ui_center-qml -o allow_other,reconnect
echo
if [ -d ${MOUNT_POINT}/qml ]; then
   echo "ui_center resources now available in ${MOUNT_POINT}"
else
   echo "Error: ui_center resources not available. Check error outputs above."
fi
echo

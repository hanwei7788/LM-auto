#!/bin/bash
#
# This fixes existing lm lxc containers for newer versions 
# of LXC (2.1 >). Assuming container has snap0 named snapshot.
#
# usage: fix-lxc-container.sh <containername>

CONTAINER=$1

lxc-update-config -c  ~/.config/lxc/default.conf
lxc-stop -n $CONTAINER -P/var/lib/lm-sdk/$USER/containers
sudo chown -R $USER:$USER /var/lib/lm-sdk/$USER/containers/$CONTAINER
cp /var/lib/lm-sdk/$USER/containers/$CONTAINER/config-lm /tmp/config-lm-$CONTAINER
lxc-snapshot --name $CONTAINER -P/var/lib/lm-sdk/$USER/containers -r snap0
lxc-update-config -c /var/lib/lm-sdk/$USER/containers/$CONTAINER/config
lxc-snapshot --name $CONTAINER -P/var/lib/lm-sdk/$USER/containers -d snap0
lxc-snapshot --name $CONTAINER -P/var/lib/lm-sdk/$USER/containers -d snap1
lxc-snapshot --name $CONTAINER -P/var/lib/lm-sdk/$USER/containers -d snap2
lxc-snapshot --name $CONTAINER -P/var/lib/lm-sdk/$USER/containers -N snap0
mv /tmp/config-lm-$CONTAINER /var/lib/lm-sdk/$USER/containers/$CONTAINER/config-lm
sudo chown -R $USER:$USER /var/lib/lm-sdk/$USER/containers/$CONTAINER
echo 
echo Container fixed.
echo List of snapshots - you should only see snap0 below:
lxc-snapshot --name lm-cutedriver -P/var/lib/lm-sdk/$USER/containers -L
echo


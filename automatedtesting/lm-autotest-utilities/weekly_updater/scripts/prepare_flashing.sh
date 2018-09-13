#!/bin/bash

device_ip="$1"
zip_url="$2"
dav_username="$3"
dav_password="$4"

MOUNTPOINT=/mnt

sshcmd () {
  sshpass -p skytree ssh -T -o StrictHostKeyChecking=no root@$device_ip "$@"
  return $?
}

sshcmd umount /dev/sda1
sshcmd mount -o rw /dev/sda1 $MOUNTPOINT/
sshcmd rm -rf "$MOUNTPOINT/lm-update*/"

zip_file=$MOUNTPOINT/update.zip
if ! sshcmd curl -k -u $dav_username:$dav_password $zip_url -o $zip_file ; then
  echo "Error in downloading image" >&2
  exit 1
fi

sshcmd busybox-static unzip -o -d $MOUNTPOINT/ $zip_file
sshcmd rm $zip_file
sshcmd "echo 1 > /sys/kernel/recovery/recovery"
sshcmd sync
sshcmd umount $MOUNTPOINT/

exit 0

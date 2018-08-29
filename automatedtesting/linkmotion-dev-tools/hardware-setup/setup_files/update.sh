#!/bin/sh
#
# This updates LM hardware with a new system image.
#

# exit on any error
set -e

mount /dev/mmcblk3p6 /mnt/
cd /mnt/
echo "Copy-paste a link to a system image .zip here:"
read URL
curl -u linkmotion@nomovok.com -O ${URL}
busybox-static unzip *.zip
rm *.zip
echo 1 > /sys/kernel/recovery/recovery
reboot


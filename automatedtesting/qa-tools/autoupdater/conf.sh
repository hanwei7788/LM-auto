#!/bin/bash

auth_url="https://auth.nomovok.info"
latest_auto_url=https://dav.nomovok.info/C4C/images/imx6-0.20-lm_autoos-nightly-devel/latest
latest_ivi_url=https://dav.nomovok.info/C4C/images/imx6-0.20-lm_ivios-nightly-container/latest

mountpoint=/mnt
write_rootfs=./write_rootfs.sh

autoos_img_pattern=imx*autoos*.ext4fs.xz
ivios_img_pattern=imx*ivios*.ext4fs.xz

autoos_partition=/dev/mmcblk3p2
ivios_partition=/dev/mmcblk3p4

issue_path=/etc/issue

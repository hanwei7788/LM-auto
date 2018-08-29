#!/bin/bash

usage()
{
	echo ""
	echo "Usage: $(basename $0 .sh) [-r|--rootfs rootfs] [-p|--partition partition]"
	echo "   or: $(basename $0 .sh) [-h|--help]"
	echo ""
	echo "Automates the steps to write a rootfs (.xz file) to a given partition using 'dd'."
	echo "C4C setup requires it to be the 2nd partition of the SD card. Check 'dmesg' when"
	echo "inserting the card to know the device filename of the partition, e.g. '/dev/sdb2'"
	echo ""
	echo "e.g.:"
	echo "   $(basename $0 .sh) -r sabrelite-testing-20150120-1110.ext4fs.xz -p /dev/sdb2"
	echo ""
	echo "rootfs can be downloaded from https://dav.nomovok.info/C4C/releases/ (requires auth)."
	echo "See Release Notes for more information."
	echo ""
}

check_params()
{
	local _tmp=$(eval echo \$$1)

	until [ -e "$_tmp" ]; do
		! [ "$_tmp" == "" ] && echo -n "'$_tmp' not found. "
		read -e -p "Enter $2 (empty to quit): " _tmp
		[ "$_tmp" == "" ] && return 1
	done

	eval "$1='$_tmp'"
	return 0
}

find_current_rootfs()
{
	local _tmp=$(stat --format '%04D' /)
	for device in $(blkid -o device); do
		[ "$_tmp" == "$(stat --format '%02t%02T' "$device")" ] && echo "$device" && break
	done
	return 0
}

proceed()
{
	echo ""
	echo "Extracting '$1' and writing to '$2'... This will take a few minutes..."

	umount $2
	xz -dc "$1" | dd of=$2 obs=1M
	[ $? -eq 0 ] && e2fsck -f $2
	[ $? -eq 0 ] && resize2fs $2
	local _mmc2_mnt=/tmp/c2
	mkdir -p $_mmc2_mnt
	[ $? -eq 0 ] && mount -t ext4 $2 $_mmc2_mnt
	[ $? -eq 0 ] && echo -n "rootfs version information: " && cat $_mmc2_mnt/etc/issue 
	# RW images do not have /etc/issue file so do not check return status
	umount $_mmc2_mnt
	[ $? -eq 0 ] && rm -rf $_mmc2_mnt
	return $?
}


rootfs=
mmc2=
yes=

[ $# -eq 0 ] && usage

while [ "$1" != "" ]; do
	case $1 in
		-r | --rootfs )
			shift
			rootfs=$1
			;;
		-p | --partition )
                        shift
                        mmc2=$1
                        ;;
		-y | --yes )
                        yes=y
                        shift
                        ;;
		-h | --help )
                        usage
                        exit
                        ;;
		-- )
                        break
                        ;;
		* )
                        ;;
	esac
	shift
done

[ $EUID -ne 0 ] && echo "ERROR: This script must be run as root." && exit 1

check_params rootfs "rootfs (.xz file) filename"
[ $? -ne 0 ] && exit 2
check_params mmc2 "partition to write to, e.g. '/dev/sdb2', "
[ $? -ne 0 ] && exit 2

[ "$yes" == "" ] && read -p "Write rootfs '$rootfs' to partition '$mmc2' (y/n)? " yes

case $yes in
	[yY]* )
		if [ "$mmc2" == "$(find_current_rootfs)" ] || [ "$(grep -o $mmc2 /proc/cmdline)" == "$mmc2" ]; then
			echo ""
			echo "------------------------------------------------------"
			echo "FATAL ERROR: $mmc2 is the current root filesystem!"
			echo "Run 'mount' to double check."
			echo "WILL NOT PROCEED. EXITING."
			echo "------------------------------------------------------"
			echo ""
			exit 4
		fi
		proceed "$rootfs" "$mmc2"
		ret=$?
		echo "DONE! Check console log for results or errors, if any."
		;;
	* )
		echo "GIVEN UP!"
		ret=3
		;;
esac

exit $ret

#!/bin/bash

usage()
{
	echo ""
	echo "Usage: $(basename $0 .sh) <device node>"
	echo "e.g.:"
	echo "   $(basename $0 .sh) /dev/sdb"
	echo ""
	echo "WARNING: All existing partitions and data on the device will be destroyed by the script!"
	echo ""
}

find_current_rootfs()
{
	local _tmp=$(stat --format '%04D' /)
	for device in $(blkid -o device); do
		[ "$_tmp" == "$(stat --format '%02t%02T' "$device")" ] && echo "$device" && break
	done
	return 0
}

[ $EUID -ne 0 ] && echo "ERROR: This script must be run as root." && exit 1

[ $# -eq 0 ] && usage && exit 0

node=$1

if [ "$(find_current_rootfs | grep -o $node)" ] || [ "$(grep -o $node /proc/cmdline)" == "$node" ]; then
			echo ""
			echo "------------------------------------------------------"
			echo "FATAL ERROR: $node is hosting the current root filesystem!"
			echo "Run 'mount' to double check."
			echo "WILL NOT PROCEED. EXITING."
			echo "------------------------------------------------------"
			echo ""
			exit 2
fi

echo ""
echo "WARNING: All existing partitions and data on the device will be destroyed by the script!"
echo "If you do not want to proceed, answer No to the question after device unmount."
echo ""

# Try to unmount the device
echo "Unmounting the device..."
umount ${node}*
echo "If the partition has not been used yet, it's ok if this fails."
echo "If the partition has been used, something is wrong you should NOT continue if this failed."
echo
read -p "Continue (y/N)? " yes

case $yes in
	[yY]* )
		;;
	* )
		echo "Unmount the device and try again."
		exit 3
		;;
esac

# Partition labels
SECUREBOOT_LABEL=SECBOOT    # 1st partition, for Secure boot
AUTOOS_RO_LABEL=AUTOOS_RO   # 2nd partition, for Auto OS RO rootfs
AUTOOS_RW_LABEL=AUTOOS_RW   # 3rd partition, for Auto OS RW rootfs
IVIOS_RO_LABEL=IVIOS_RO     # 4th partition, for IVI OS RO rootfs
IVIOS_RW_LABEL=IVIOS_RW     # 5th partition, for IVI OS RW rootfs
SECCONT_RO_LABEL=SECCONT_RO # 6th partition, for Secure container RO rootfs
SECCONT_RW_LABEL=SECCONT_RW # 7th partition, for Secure container RW rootfs

echo ""
echo "WARNING: GPT partition table will overwite U-Boot in eMMC MBR."
echo "There is no problem if you are writing to USB stick."
echo "If you are writing to eMMC and you have U-Boot in eMMC MBR it needs to be moved to eMMC boot0 partition."
echo "For more information see https://wiki.nomovok.info/C4C/index.php/Link_Motion_Hardware:U-Boot#Check_eMMC_Boot_Info"
echo "and https://wiki.nomovok.info/C4C/index.php/Link_Motion_Hardware:U-Boot#Write_U-Boot_to_eMMC_boot0_partition"
echo ""
read -p "Do you have U-Boot in eMMC boot0 or are you writing to USB stick (y/N)?" yes
case $yes in
	[yY]* )
		;;
	* )
		exit 4
		;;
esac

disk_size=$(sfdisk -s $node)
if [ "$disk_size" -gt 15000000 ]; then
    echo "Disk size" $disk_size "creating large partitions"
    echo "Partitions are targeted for 16 GB SLC mode (Halti eMMC SLC size 16 GB, MLC size 32 GB)"
    echo "or 16 GB in MLC mode (M2.1 eMMC SLC size 8 GB, MLC size 16 GB)"
    # Partition sizes, in MiB
    # Modify these parameters to fit your own usage
    MBR_ROM_SIZE=10       # GPT, U-boot environment
    SECUREBOOT_SIZE=200   # MiB
    AUTOOS_RO_SIZE=2240   # MiB
    AUTOOS_RW_SIZE=560    # MiB
    IVIOS_RO_SIZE=7300    # MiB
    IVIOS_RW_SIZE=2000    # MiB
    SECCONT_RO_SIZE=2160  # MiB
    #SECCONT_RW_SIZE=     # undefined == rest of the space
elif [ "$disk_size" -gt 6000000 ]; then
    # Partition sizes, in MiB
    # Modify these parameters to fit your own usage
    echo "Disk size" $disk_size "creating small partitions"
    echo "Note, disk parititons are smaller than designed for real system. This is expected"
    echo "e.g. with 8 GB USB stick"
    MBR_ROM_SIZE=10       # GPT, U-boot environment
    SECUREBOOT_SIZE=200   # MiB
    AUTOOS_RO_SIZE=1400   # MiB
    AUTOOS_RW_SIZE=700    # MiB
    IVIOS_RO_SIZE=1400    # MiB
    IVIOS_RW_SIZE=700     # MiB
    SECCONT_RO_SIZE=1400  # MiB
    #SECCONT_RW_SIZE=     # undefined == rest of the space
else
    echo "Disk is too small to create partitions"
    exit 5
fi

# Sector size = 512B, 1MB = 2048 sectors
MB=2048

# Convert partition size in MB to number of sectors
MBR_ROM_SIZE=$(( MBR_ROM_SIZE * MB ))
SECUREBOOT_SIZE=$(( SECUREBOOT_SIZE * MB ))
AUTOOS_RO_SIZE=$(( AUTOOS_RO_SIZE * MB ))
AUTOOS_RW_SIZE=$(( AUTOOS_RW_SIZE * MB ))
IVIOS_RO_SIZE=$(( IVIOS_RO_SIZE * MB ))
IVIOS_RW_SIZE=$(( IVIOS_RW_SIZE * MB ))
SECCONT_RO_SIZE=$(( SECCONT_RO_SIZE * MB ))
#SECCONT_RW_SIZE=$(( SECCONT_RW_SIZE * MB ))

# Calculate partition start positions, in number of sectors
SECUREBOOT_START=${MBR_ROM_SIZE}
AUTOOS_RO_START=$(( SECUREBOOT_SIZE + SECUREBOOT_START ))
AUTOOS_RW_START=$(( AUTOOS_RO_SIZE + AUTOOS_RO_START ))
IVIOS_RO_START=$(( AUTOOS_RW_SIZE + AUTOOS_RW_START ))
IVIOS_RW_START=$(( IVIOS_RO_SIZE + IVIOS_RO_START ))
SECCONT_RO_START=$(( IVIOS_RW_SIZE + IVIOS_RW_START ))
SECCONT_RW_START=$(( SECCONT_RO_SIZE + SECCONT_RO_START ))

# Destroy the existing GPT partition table
dd if=/dev/zero of=${node} bs=512 count=34

# Call sfdisk to create the new partition table
sfdisk -X gpt --force -uS ${node} << EOF
${SECUREBOOT_START},${SECUREBOOT_SIZE},L
${AUTOOS_RO_START},${AUTOOS_RO_SIZE},L
${AUTOOS_RW_START},${AUTOOS_RW_SIZE},L
${IVIOS_RO_START},${IVIOS_RO_SIZE},L
${IVIOS_RW_START},${IVIOS_RW_SIZE},L
${SECCONT_RO_START},${SECCONT_RO_SIZE},L
${SECCONT_RW_START},${SECCONT_RW_SIZE},L
EOF

if test `expr match "$node" "\/dev\/mmcblk.*"` -ne 0; then
    part="p"
else
    part=""
fi

# Formatting and labelling
mke2fs -t ext4 -L ${SECUREBOOT_LABEL} ${node}${part}1
mke2fs -t ext4 -L ${AUTOOS_RO_LABEL}  ${node}${part}2
mke2fs -t ext4 -L ${AUTOOS_RW_LABEL}  ${node}${part}3
mke2fs -t ext4 -L ${IVIOS_RO_LABEL}   ${node}${part}4
mke2fs -t ext4 -L ${IVIOS_RW_LABEL}   ${node}${part}5
mke2fs -t ext4 -L ${SECCONT_RO_LABEL} ${node}${part}6
mke2fs -t ext4 -L ${SECCONT_RW_LABEL} ${node}${part}7

# Check the status
echo "Done. Warnings about partitions not starting or ending at a cylinder boundary can be safely ignored."
echo ""
echo "New device partition layout:"
lsblk ${node}
echo ""

echo "ALL DONE!"

exit 0
## EOF

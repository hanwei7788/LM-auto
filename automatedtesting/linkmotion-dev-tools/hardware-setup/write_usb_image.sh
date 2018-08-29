#!/bin/bash

# params:
# - image file <for example imx6-nightly-20150514-0112.ext4fs.xz>
# - usb device <for example /dev/sdc>

IMAGE_FILE=$1
USB_DEVICE=$2

if [ ! -f "$IMAGE_FILE" ]; then
    echo "Image file $IMAGE_FILE doesn't exist!"
    exit 1
fi

if [ ! -b "$USB_DEVICE" ]; then
    echo "Device file $USB_DEVICE doesn't exist!"
    exit 1
fi

if [ ! -f /usr/bin/pv ]; then
    echo "Please install pv - sudo apt-get install pv"
    exit 1
fi

PARTITION=${USB_DEVICE}2

if [ ! -b "$PARTITION" ]; then
    echo "Partition $USB_DEVICE doesn't exist!"
    exit 1
fi

echo "Going to write $IMAGE_FILE to partition $PARTITION."
echo
echo "Info on the disk, check that it's the correct one:"
echo
udevadm info -n $USB_DEVICE |grep ID_MODEL=
lsblk -f $USB_DEVICE
echo
echo "Press enter to continue, ctrl-C to cancel.."
read
echo "Writing, stand by.."
cat $IMAGE_FILE | xz -d | pv -s 700m | sudo dd of=$PARTITION bs=1M 
echo "Checking partition.."
sudo fsck -f $PARTITION
echo "Resizing partition.."
sudo resize2fs $PARTITION
sync
echo
echo "Image written to $PARTITION. You may now remove the device. It's synced already."


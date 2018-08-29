#!/bin/bash
# Check currently used partition on SUT v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

FLASHPARTITION1="/dev/mmcblk3p1"
FLASHPARTITION2="/dev/mmcblk3p2"

printf "Auto: Start partition check\n"
RESULTS=$(sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'cat /proc/cmdline')
echo $RESULTS | grep -o "\w*root=/dev/mmc\w*" > "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/SUT_cmdline.txt"
CMDLINERESULT=$(cat "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/SUT_cmdline.txt")
CURRENTPARTITION=${CMDLINERESULT:5}

> "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/PartitionToFlash.txt"

if [ "$CURRENTPARTITION" == "$FLASHPARTITION1" ]
then
	echo $FLASHPARTITION2 > "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/PartitionToFlash.txt"
fi
if [ "$CURRENTPARTITION" == "$FLASHPARTITION2" ]
then
	echo $FLASHPARTITION1 > "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/PartitionToFlash.txt"
fi
printf "Auto: Partition check done\n"

exit 0



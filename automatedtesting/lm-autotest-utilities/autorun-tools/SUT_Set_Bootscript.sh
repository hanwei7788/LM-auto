#!/bin/bash
# SUT Set Bootscript v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

FLASHPARTITION1="/dev/mmcblk3p1"
FLASHPARTITION2="/dev/mmcblk3p2"

PARTITIONTOFLASH=$(cat "/home/autotest/automatedtesting/c4c-functional-tests/TestReports_$1/PartitionToFlash.txt")
printf "$PARTITIONTOFLASH\n"

printf "Auto: Start setting bootscript\n"

if [ "$PARTITIONTOFLASH" == "$FLASHPARTITION1" ]
then
	sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'cd /tmp/mnt/p3/.bootscripts && ln -sf lm_bootscript_p1.scr lm_bootscript.scr'
	printf "Auto: Set Bootscript to P1\n"
fi
if [ "$PARTITIONTOFLASH" == "$FLASHPARTITION2" ]
then
	sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'cd /tmp/mnt/p3/.bootscripts && ln -sf lm_bootscript_p2.scr lm_bootscript.scr'
	printf "Auto: Set Bootscript to P2\n"
fi

printf "Auto: Setting bootscript done\n"

exit 0

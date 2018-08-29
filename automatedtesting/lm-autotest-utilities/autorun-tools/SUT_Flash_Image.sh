#!/bin/bash
# SUT Flash Image v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

PARTITIONTOFLASH=$(cat "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/PartitionToFlash.txt")

printf "Auto: Stop UI\n"
if timeout 30 sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'systemctl stop user@20000'
then
  echo "UI stop exit OK"
else
  echo "UI stop exit by timer"
fi
printf "Auto: Stop UI done\n"

printf "Auto: Mounting p3\n"
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'mkdir -p /tmp/mnt/p3/'
RESULTS2=$(sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'mount /dev/mmcblk3p3 /tmp/mnt/p3/')
printf "Auto: Mounting done\n"

printf "Auto: Start flashing $3 to $PARTITIONTOFLASH\n"
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" "/tmp/mnt/p3/tools/write_rootfs_auto.sh -p $PARTITIONTOFLASH -r $3"
printf "Auto: Flashing done\n"


exit 0



#!/bin/bash
#This script handles log gathering for sufu.
#Parameters to give:
#1. name of the device
#2. now timestamp, which is used to determine test folder
name=$1
now=$2
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
source "$thisdir/Functions.sh"
devicefolder="$testroot/TestReports_$name"
testfolder="$devicefolder/$now"
source "$devicefolder/image.conf"
##############################################################
#Getting the logs from device
#This is not a beauty,
#but necessary way to get the logs without manual intervention
##############################################################
echo "Getting logs from device"
if [ "$can" == "1" ] ; then
  can_message "poweroff"
  sleep 10
  can_message "poweron"
  sleep 30
else
  tdtool --off $switch
  sleep 10
  tdtool --on $switch
  sleep 30
fi

ssh-keygen -R $ip
ssh_cmd "mount -o remount,rw /"
if [[ $? != 0 ]]; then
  echo "Network problem with SSH command"
  exit 1
fi
ssh_cmd "mkdir usb"
ssh_cmd "umount /dev/sda*"
ssh_cmd "mount /dev/sda1 usb"
ssh_cmd "mount -o remount,rw usb"
ssh_cmd "mkdir usb/lm-log"
ssh_cmd "sync"
ssh_cmd "umount usb"
ssh_cmd "mount /dev/sda1 usb"
sleep 30
bash $scriptfolder/Ping.sh $name
if [[ $? != 0 ]]; then
  echo "SUT not on. Cannot get logs."
  exit 1
fi
sshpass -p $ssh_pw scp root@$ip:/media/usbhd*/lm-log*/log $testfolder/log.txt
ssh_cmd "sync"
if [[ $? != 0 ]]; then
	echo "Network error. Device not on?"
	exit 1
fi
ssh_cmd "mount -o remount,rw /media/usbhd*/"
ssh_cmd "rm -r /media/usbhd*/lm-log*"
ssh_cmd "sync"
##################
#Handling the logs
##################
echo "Using sufu.sh script to handle logs"
bash $sufufolder/logsplitter.sh $testfolder/log.txt
if [[ $software_type == "pallas" ]]; then
  ls $testfolder/log.txt-boot-00* | xargs -L 1 bash $sufufolder/sufu-pallas.sh
else
  ls $testfolder/log.txt-boot-00* | xargs -L 1 bash $sufufolder/sufu.sh
fi
cat $testfolder/log.txt-*.csv > $testfolder/boots.csv
rm $testfolder/log.txt-*.csv
exit 0

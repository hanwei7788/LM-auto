#!/bin/bash
#Needed parameters:
#1. Name of the device that is used with the TestResults folder also
#2. Ip of the device
#3. Power switch of the device
#4. CAN interface of the device
#############################################################
#THIS SCRIPT ASSUMES THAT THE DEVICE HAS TESTABILITY RECOVERY
#############################################################
name=$1
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
devicefolder="$testroot/TestReports_$name"
source "$devicefolder/image.conf"
source "$thisdir/Functions.sh"

dav_username=$(get_config_param auth dav username)
dav_password=$(get_config_param auth dav password)

############################
#New zip available, updating
############################
echo "Doing pre-update checks"
ssh-keygen -R $ip
bash $scriptfolder/Ping.sh $name
if [[ $? != 0 ]]; then
	if [[ $can == 1 ]]; then
    can_message "poweron"
  else
    tdtool --on $switch
  fi
	sleep 30
	bash $scriptfolder/Ping.sh $name
	if [[ $? != 0 ]]; then
		echo "Ping failed, something broken."
		exit 1
	fi
fi
###################################
#Update recovery first if available
###################################
echo "Checking whether to update recovery"
locallatestrecovery="/tmp/$name-latest_recovery_zip.txt"
curl -k -u $dav_username:$dav_password -o $locallatestrecovery $dl_recovery_url
latest_recovery=$(grep .combined$ $locallatestrecovery)
last_installed_recovery=$(cat $devicefolder/last_installed_recovery.txt)
if [[ $latest_recovery != $last_installed_recovery ]]; then
  echo "New recovery found, updating..."
  ssh_cmd "curl -k -u $dav_username:$dav_password -o /tmp/recovery.combined $latest_recovery"
  if [[ $? != 0 ]]; then
    echo "Network error. Device not on?"
    exit 1
  fi
  ssh_cmd "echo 0 > /sys/block/mmcblk3boot1/force_ro"
  ssh_cmd "busybox dd if=/tmp/recovery.combined of=/dev/mmcblk3boot1 bs=1M conv=fsync"
  ssh_cmd "sync"
  echo $latest_recovery > $devicefolder/last_installed_recovery.txt
  echo "Recovery updated."
else
  echo "Latest recovery already installed"
fi
#######################################
#Take the latest zip from zip_queue.txt
#######################################
echo "Proceeding with recovery update"
next_zip=$(cat $devicefolder/zip_queue.txt|head -n 2|tail -n 1)
ssh_cmd "curl -k -u $dav_username:$dav_password -o /tmp/imx6zip.zip $next_zip"
if [[ $? != 0 ]]; then
	echo "Network error. Device not on?"
	exit 1
fi
###############################
#Unzip and copy the file to usb
###############################
ssh_cmd "busybox-static unzip -o /tmp/imx6zip.zip -d /tmp/"
echo "Removing the old lm-update folder and copying new lm-update to usb ..."
ssh_cmd "mount -o remount,rw /media/usbhd*"
ssh_cmd "rm -r /media/usbhd*/lm-update*"
ssh_cmd "cp -r /tmp/lm-update /media/usbhd*/"
ssh_cmd "sync"
sshpass -p $ssh_pw scp root@$ip:/tmp/sources.txt /tmp/$name-sources.txt
if [[ $? != 0 ]]; then
  "Echo problem getting sources.txt from the device"
  exit 1
fi
echo "Versions from sources.txt, storing data for further use..."
autoos_version=$(cat /tmp/$name-sources.txt |grep autoos |head -n 1)
autoos_version=${autoos_version%-*}
echo "Autoos $autoos_version"
ivios_version=$(cat /tmp/$name-sources.txt |grep ivios |head -n 1)
ivios_version=${ivios_version%-*}
echo "Ivios $ivios_version"
echo "Setting recovery flag and rebooting to start flashing..."
ssh_cmd "echo 1 > /sys/kernel/recovery/recovery"
if [[ $can == 1 ]]; then
  can_message "poweroff"
else
  tdtool --off $switch
fi
sleep 30
bash $scriptfolder/Ping.sh $name
if [[ $? == 0 ]]; then
  echo "System not off. Switch broken again?"
	exit 1
fi
############################################
#Give the device 8 minutes of time to update
############################################
echo "Starting flashing sequence. This will take some time."
if [[ $can == 1 ]]; then
  can_message "poweron"
else
  tdtool --on $switch
fi
round=1
while :
do
  sleep 30
  bash $scriptfolder/Ping.sh $name
  if [[ $? == 0 ]];then
    echo "Device awake after update"
    sleep 30
    break
  fi
  can_message "poweron"
  round=$(($round+1))
  if [[ $round == 12 ]];then
    echo "Device still not updated. Something broken?"
    exit 1
  fi
done
########################################
#Doing one more boot before testing ping
########################################
echo "Powercycling one more time"
if [[ $can == 1 ]]; then
  can_message "poweroff"
else
  tdtool --off $switch
fi
sleep 30
bash $scriptfolder/Ping.sh $name
if [[ $? == 0 ]]; then
  echo "System not off. Switch broken again?"
	exit 1
fi
if [[ $can == 1 ]]; then
  can_message "poweron"
else
  tdtool --on $switch
fi
sleep 30
########################################
#Ping to check that the update succeeded
########################################
bash $scriptfolder/Ping.sh $name
if [[ $? != 0 ]]; then
	echo "Ping failed, update failed or image broken?"
	exit 1
fi
echo "Checking that versions match with sources.txt"
autoos_version2=$(ssh_cmd "cat /etc/issue")
echo "/etc/issue  $autoos_version2"
echo "sources.txt $autoos_version"
if [[ $autoos_version != $autoos_version2 ]]; then
  echo "Autoos versions do not match"
  exit 1
fi
echo "Autoos OK"
ivios_version2=$(ssh_cmd "cat /usr/lib/lm_containers/ivi/rootfs/etc/issue")
echo "/etc/issue  $ivios_version2"
echo "sources.txt $ivios_version"
if [[ $ivios_version != $ivios_version2 ]]; then
  echo "Ivios versions do not match"
  exit 1
fi
echo "Ivios OK"
echo "Versions match"
#####################################################
#Change the last_installed_zip and last_test_combiner
#####################################################
echo $next_zip > $devicefolder/last_installed_zip.txt
echo "$(tail -n +2 $devicefolder/zip_queue.txt)" > $devicefolder/zip_queue.txt
exit 0

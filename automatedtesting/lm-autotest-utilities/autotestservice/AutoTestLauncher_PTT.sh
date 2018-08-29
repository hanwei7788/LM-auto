#!/bin/bash
#This is the AutoTestLauncher_PTT.sh. It is meant to be run from crontab.
#This is used by the FOS device.
#Needed parameters:
#1. Name of the device that is used with the TestResults folder also
#2. Power socket of the device
name=$1
switch=$2
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
source "$thisdir/Functions.sh"

dav_username=$(get_config_param auth dav username)
dav_password=$(get_config_param auth dav password)

######
#USAGE
######
if [[ "$#" -eq 0 ]]; then
  echo "Usage: bash AutoTestLauncher_PTT.sh <DeviceName> <DeviceTdtool>"
  exit 0
fi
#####################
#Initialize variables
#####################
now=$(date +"%Y%m%d%H%M%S")
devicefolder="$testroot/TestReports_$name"
testfolder="$devicefolder/$now"
source "$devicefolder/image.conf"
########################################
#Checking if autotest is already running
########################################
autotestson=$(cat $devicefolder/autotestson.txt)
if [[ $autotestson == "yes" ]]; then
  echo "Autotests already running. Exiting with value 1."
  exit 1
fi
###################################
#Checking if new image is available
###################################
bash $scriptfolder/CheckZipQueue.sh $name
if [[ $? != 0 ]]; then
  echo "No new zip available"
  exit 1
fi
############################################
#If we got this far, we can take control of autotestson.txt
############################################
echo yes > $devicefolder/autotestson.txt
mkdir -p "$testfolder"
jiralog="$testfolder/$name-$now-jira_upload.log"
cronlog="$testfolder/$name-$now-cron.log"
imagefolder=$(mktemp -d)
if [[ $? -ne 0 ]]; then
    echo "Could not create tmp dir for image"
    rm -r $imagefolder
    echo no > $devicefolder/autotestson.txt
    exit 1
fi
echo "Starting new autotest $now on device $name" >> $cronlog
#######################################
#Take the latest zip from zip_queue.txt
#######################################
next_zip=$(cat $devicefolder/zip_queue.txt|head -n 2|tail -n 1)
curl -k -u $dav_username:$dav_password -o $imagefolder/latest.exe $next_zip
if [[ $? != 0 ]]; then
    echo "Network error. Could not download latest image" >> $cronlog
    rm -r $imagefolder
    echo no > $devicefolder/autotestson.txt
    exit 1
fi
##############################
#Remove the earlier from queue
##############################
echo "$(tail -n +2 $devicefolder/zip_queue.txt)" > $devicefolder/zip_queue.txt
echo $next_zip > $devicefolder/last_installed_zip.txt
###############
#Unzip the .exe
###############
pushd $imagefolder
7z e *.exe
popd
##############################################
#Power cycle device to enable OTG
##############################################
echo "Starting flashing sequence" >> $cronlog
tdtool --off $switch >> $cronlog
sleep 5
tdtool --on $switch >> $cronlog
sleep 2
##############################################
#Boot up FOS image
##############################################
$imxusb/imx_usb $imagefolder/u-boot-halti-ptt.imx >> $cronlog
fastboot boot $imagefolder/zImage-dtb-halti_ptt-ptt $imagefolder/initramfs.cpio.gz >> $cronlog
##############################################
#Wait for serial port to appear
##############################################
timeout_s=0
while [ ! -c /dev/ttyACM0 ]; do
    sleep 1
    timeout_s=$(($timeout_s + 1))
    if [ $timeout_s -gt 60 ]; then
        echo "Could not boot up FOS. No serial port available." >> $cronlog
        rm -r $imagefolder
        echo no > $devicefolder/autotestson.txt
        exit 1
    fi
done
########################
#Run test set
########################
cd $testroot
bash $scriptfolder/RunTestSet.sh $name $now >> $cronlog
if [[ $? != 0 ]]; then
  echo "There was an error running the test set" >> $cronlog
  rm -r $imagefolder
  echo no > $devicefolder/autotestson.txt
  exit 1
fi
echo "Test set has been run" >> $cronlog
#####################################################################
#Jira upload and slack announce depending if the test is smoke or not
#####################################################################
echo "Jira upload..." >> $cronlog
python3 $jirafolder/upload.py -n $name -t $now >> $jiralog
sleep 10
echo "Test set finished. Turning off" >> $cronlog
########################################################
#Turn device off
########################################################
tdtool --off $switch >> $cronlog
echo "Tests finished" >> $cronlog
rm -r $imagefolder
echo no > $devicefolder/autotestson.txt
exit 0

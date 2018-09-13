#!/bin/bash
#This script is used to run the current test set on the device.
#Script takes following variables as input:
#1. name of the device
#2. now timestamp, which is used to determine test folder
name=$1
now=$2
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
##################################
#Initialize variables and logfiles
#################################
devicefolder="$testroot/TestReports_$name"
testfolder="$devicefolder/$now"
source "$devicefolder/image.conf"
logfile="$testfolder/$name-$now-log_TestRun.txt"
#################
#Get the test set
#################
json_file=$(mktemp)
if ! (python3 $scriptfolder/get_test_plan_json.py $test_plan > $json_file) ; then
  echo "Could not retrieve test set!" 2>&1
  rm $json_file
  exit 1
fi
#############################################################################################
#Update tests before running them. The parameters will be moved to config file in later tasks
#############################################################################################
cd "$testroot"
git pull
#########################
#call rake to start tests
#########################
last_installed_zip=$(cat $devicefolder/last_installed_zip.txt)
echo "Running tests on image:" >> $logfile
echo $last_installed_zip >> $logfile
rake run_json["$json_file"] TESTOPTS="--sut_config=${name} --test_run_id=${now}" >> $logfile
rm $json_file
exit 0

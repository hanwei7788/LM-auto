#!/bin/bash
#This script returns 1 if there is no new zip in the queue and 0 if there is not
#This script assumes there is a file called zip_queue.txt and last_installed_zip.txt inside the device folder
#Parameters:
#1. Name of the device that is used with the TestResults folder also
#2. Device folder location
name=$1
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
devicefolder="$testroot/TestReports_$name"
#########################################
#Compare last installed and last in queue
#########################################
last_installed_zip=$(cat $devicefolder/last_installed_zip.txt)
echo "Current:"
echo $last_installed_zip
next_zip=$(cat $devicefolder/zip_queue.txt|head -n 2|tail -n 1)
echo "Next in queue:"
echo $next_zip
########################################################
#Return with corresponding value depending on the result
########################################################
if [[ $next_zip == $last_installed_zip ]]; then
	echo "No new zip available"
	exit 1
else
	echo "New zip available"
	exit 0
fi

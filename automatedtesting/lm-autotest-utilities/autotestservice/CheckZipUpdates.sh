#!/bin/bash
#This script checks new images in DAV and adds them to the queue.
#Later on the script CheckZipQueue.sh will determine from the queue whether to update or not.
name=$1
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
source "$thisdir/Functions.sh"

dav_username=$(get_config_param auth dav username)
dav_password=$(get_config_param auth dav password)

devicefolder="$testroot/TestReports_$name"
source $devicefolder/image.conf
if [[ $software_type == "FOS" ]]; then
    file_extension="ext4fs.xz"
else
    file_extension="zip"
fi
############################################################################
#Curl the latest file from dav and compare it to the latest in zip_queue.txt
############################################################################
locallatestzip="/tmp/$name-latest_zip.txt"
curl -k -u $dav_username:$dav_password -o $locallatestzip $dl_zip_url
echo "Comparing zips"
latest_zip=$(grep .${file_extension}$ $locallatestzip)
rm $locallatestzip
if [[ $latest_zip == "" ]]; then
  echo "Fetching latest from dav failed, exiting."
  exit 1
fi
echo $latest_zip
latest_zip_queue=$(tail -n 1 $devicefolder/zip_queue.txt)
echo $latest_zip_queue
#######################################################################
#Add the new image to zip_queue if it doesn't match the latest in queue
#######################################################################
if [[ $latest_zip != $latest_zip_queue ]]; then
  echo $latest_zip >> $devicefolder/zip_queue.txt
	exit 1
fi
exit 0

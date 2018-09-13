#!/bin/bash
#This script is used to update the Packages on WindowsPC.
#These packages are used with OTG flashing
#Location from where to get latest data
latestdata=$1
#######
#CONFIG
#######
thisdir=$(dirname $(realpath $0))
source "$thisdir/AutoTest.conf"
source "$thisdir/Functions.sh"

dav_username=$(get_config_param auth dav username)
dav_password=$(get_config_param auth dav password)
windows_host=$(get_config_param auth windowspc url)
windows_host_pw=$(get_config_param auth windowspc password)

echo "Getting latest package info from dav"
locallatestzip="/tmp/factory-latest_zip.txt"
curl -k -u $dav_username:$dav_password -o $locallatestzip $latestdata
if [[ $? != 0 ]]; then
  echo "Network problem from host to dav"
  exit 1
fi
lastpackage=$(grep .exe$ $locallatestzip)
packagename=$(basename $lastpackage)
if [[ $? != 0 ]]; then
  echo "Problem parsing the strings"
  exit 1
fi
windowspackages="/tmp/windowspackages.txt"
sshpass -p $windows_host_pw ssh -o StrictHostKeyChecking=no $windows_host dir C:\\ProgramData\\LinkMotion\\Packages > $windowspackages
if [[ $? != 0 ]]; then
  echo "Network problem from host to WindowsPC"
  exit 1
fi
echo "Checking if the packages need to be updated"
if [[ $(grep $packagename $windowspackages) ]]; then
  echo "Latest package already there"
else
  echo "Latest package not found."
  echo "Downloading $lastpackage to windows host"
  sshpass -p $windows_host_pw ssh -o StrictHostKeyChecking=no $windows_host curl.exe -k -u $dav_username:$dav_password -o $packagename $lastpackage
  echo "Extracting $packagename"
  sshpass -p $windows_host_pw ssh -o StrictHostKeyChecking=no $windows_host 7z e -oC:/ProgramData/LinkMotion/Packages/$packagename $packagename
  echo "Packages on WindowsPC updated"
  echo "Removing unneeded files..."
  sshpass -p $windows_host_pw ssh -o StrictHostKeyChecking=no $windows_host del $packagename
fi
echo "Packages up to date"
exit 0

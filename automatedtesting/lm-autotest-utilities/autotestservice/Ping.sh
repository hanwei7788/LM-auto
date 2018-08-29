#!/bin/bash
#Easy script for pinging the device to determine whether it is on and responsive
#Takes only one variable, name of the device
name=$1
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
devicefolder="$testroot/TestReports_$name"
source "$devicefolder/image.conf"
###########
#Start Ping
###########
echo "Pinging $ip..."
for i in {1..5}
do
  value=$(ping -q -c 1 $ip)
  if [[ $? -eq 0 ]] ; then
    echo "Ping successful"
    exit 0
  fi
done
echo "Not responging to ping"
exit 1

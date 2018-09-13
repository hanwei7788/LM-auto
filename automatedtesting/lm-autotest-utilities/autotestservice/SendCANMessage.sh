#!/bin/bash
#This script is used for sending CAN messages to device
#Parameter is the can interface, of which the wanted device is connected to
name=$1
interface=$2
command=$3
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
devicefolder="$testroot/TestReports_$name"
source "$devicefolder/image.conf"
#Sending the command to device
echo "Sending $command to device on $interface"
$canconfigfolder/can-simulator-ng --cfg="$canconfigfolder/$software_type/can.cfg" --dbc="$canconfigfolder/$software_type/can.dbc" -i "$interface" send $command
exit 0

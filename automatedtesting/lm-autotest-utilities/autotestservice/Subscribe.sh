#!/bin/bash
echo "Welcome to subrscriber program! Please answer the following questions to setup new device"

echo "Name of the device:"
read name
if [[ $name == "" ]]; then
    echo "Name of the device cannot be empty"
    exit 1
fi
sleep 0.5
echo "IP of the device:"
read ip
if [[ $ip == "" ]]; then
    echo "IP of the device cannot be empty"
    exit 1
fi
sleep 0.5
echo "Tdtool switch of the device:"
read switch
if [[ $switch == "" ]]; then
    echo "Tdtool switch of the device cannot be empty"
    exit 1
fi
sleep 0.5
echo "Specify the hardware of the device:"
read hardware
if [[ $hardware == "" ]]; then
    echo "You have to specify hardware"
    exit 1
fi
sleep 0.5
echo "Specify the software type for the device (argo, pallas):"
read software
if [[ $software == "" ]]; then
    echo "You have to specify software type"
    exit 1
fi
sleep 0.5
echo "Specify the software version (for example 0.30, 0.31 etc):"
read version
if [[ $version == "" ]]; then
    echo "You have to specify software version"
    exit 1
fi
sleep 0.5
echo "CAN interface of the device(Optional):"
read interface
sleep 0.5
echo "URL of the zips for the device (whole url with https://dav.nomovok.com included)(Optional):"
read url
sleep 0.5
echo "Test plan for the device(Optional):"
read testplan
sleep 0.5
echo "Test type (smoke, nightly, stability)(Optional):"
read type
sleep 0.5
#######
#CONFIG
#######
thisdir=$(dirname $0)
source "$thisdir/AutoTest.conf"
devicefolder="$testroot/TestReports_$name"
#######################
#Current crontab saving
#######################
currentcron=/tmp/current_cron.txt
crontab -l > $currentcron
currentconfig=/tmp/currentconfig.txt
cat $testroot/config.ini > $currentconfig
currenttdriver=/tmp/currenttdriver.txt
cat $testroot/real_tdriver_parameters.xml > $currenttdriver
################################################################
#Check if any of the variables can already be found from crontab
################################################################
if grep $name $currentcron; then
  echo "SuT name already in crontab"
  exit 1
elif grep $ip $currentcron; then
  echo "SuT IP already in crontab"
  exit 1
elif grep $switch $currentcron; then
  echo "TdTool switch already in crontab"
  exit 1
elif [[ $interface != "" ]]; then
  if grep $interface $currentcron; then
    echo "Can interface already in crontab"
    exit 1
  fi
fi
if grep $name $currentconfig; then
  echo "Device name already in config.ini"
  exit 1
fi
####################################
#Create device folder for the device
####################################
if [ -d $devicefolder ]; then
  echo "Device folder already exists"
  exit 1
else
  mkdir -p $devicefolder
  echo "Created device folder $devicefolder"
fi
###################################
#Create image.conf in device folder
###################################
echo "Creating variables inside image.conf"
echo "sut_config=$name" >> $devicefolder/image.conf
echo "sut_ip=$ip" >> $devicefolder/image.conf
echo "sut_power=$switch" >> $devicefolder/image.conf
echo "dl_zip_url=$url" >> $devicefolder/image.conf
echo "test_plan=$testplan" >> $devicefolder/image.conf
echo "software_type=$software" >> $devicefolder/image.conf
echo "hardware=$hardware" >> $devicefolder/image.conf
echo "test=$type" >> $devicefolder/image.conf
echo "version=$version" >> $devicefolder/image.conf
#####################################
#Create the variable files for device
#####################################
echo "Creating files inside device folder"
echo no > $devicefolder/autotestson.txt
echo LastZip > $devicefolder/last_installed_zip.txt
echo LastZip > $devicefolder/zip_queue.txt
###############
#Add config.ini
###############
echo "Adding new device to config.ini"
configfile=$testroot/config.ini
echo "" >> $configfile
echo [$name] >> $configfile
if [[ $software_type == "pallas" ]]; then
  echo "center_resolution = 1024x600" >> $configfile
  echo "language = zh_CN"
else
  echo "center_resolution = 1024x768" >> $configfile
  echo "language = en_US" >> $configfile
fi
echo "sutid = $name"  >> $configfile
echo "report_folder = TestReports_$name"  >> $configfile
echo "wifi_network = Pena-WPA2" >> $configfile
echo "wifi_password = 2077posy2765" >> $configfile
echo "fm_channel_freq = 95.7" >> $configfile
echo "fm_channel_rds = CITY" >> $configfile
echo "rds_names = CITY,Classic,FUN TRE,KISS,LOOP,NRJ,SUOMIPOP,MOREENI,PLAY,BASSO,T66-RDS,MUSA TRE,YLE TRE,AALTO,ISKELMA,ROCK,SUN,YLEX,MANSE" >> $configfile
echo "rds_freqs = 95.7,92.2,89.0,89.6,105.2,90.0,91.6,98.4,88.7,103.1,88.5,100.5,99.9,105.6,100.9,104.2,107.8,93.7,99.1" >> $configfile
echo "rds_enabled = false" >> $configfile
echo "lowest_fm_frequency = 88.0" >> $configfile
echo "highest_fm_frequency = 108.0" >> $configfile
echo "lowest_am_frequency = 540" >> $configfile
echo "highest_am_frequency = 1600" >> $configfile
if [[ $software_type == "pallas" ]]; then
  echo "can_dbc = /home/autotest/automatedtesting/argo_functional_tests/tests/comfort_pallas/can.dbc" >> $configfile
  echo "can_cfg = /home/autotest/automatedtesting/argo_functional_tests/tests/comfort_pallas/can.cfg" >> $configfile
fi
#############################
#Add real_tdriver_parameters
#############################
echo "Adding new device to real_tdriver_parameters.xml"
tdriverfile=$testroot/real_tdriver_parameters.xml
sed -i --follow-symlinks '$i\ \ \ \ \ \ \ \ <sut id="'$name'" template="qt">' $tdriverfile
sed -i --follow-symlinks '$i\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ <parameter name="qttas_server_ip" value="'$ip'" />' $tdriverfile
sed -i --follow-symlinks '$i\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ <parameter name="qttas_plugin_timeout" value="40000" />' $tdriverfile
sed -i --follow-symlinks '$i\ \ \ \ \ \ \ \ </sut>' $tdriverfile
##########################
#Add new device to crontab
##########################
if [[ $type == "nightly" ]] || [[ $type == "smoke" ]]; then
  echo "Adding new device to crontab"
  (crontab -l ; echo "")| crontab -
  (crontab -l ; echo "#$name")| crontab -
  (crontab -l ; echo "25 * * * * bash $scriptfolder/AutoTestLauncher.sh $name $ip $switch $interface")| crontab -
  (crontab -l ; echo "*/5 * * * * bash $scriptfolder/CheckZipUpdates.sh $name")| crontab -
fi
#####
#DONE
#####
echo "Removing /tmp files..."
rm $currentcron
rm $currentconfig
rm $currenttdriver
echo "Device added"
exit 0

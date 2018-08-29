#!/bin/bash
#This is the AutoTestLauncher.sh. It is meant to be run from crontab.
#If you do not give 4th parameter (CAN interface) the script will use tdtool instead.
#Needed parameters:
#1. Name of the device that is used with the TestResults folder also
name=$1
#######
#CONFIG
#######
thisdir=$(dirname $(realpath $0))
source "$thisdir/AutoTest.conf"
######
#USAGE
######
if [[ "$#" -eq 0 ]]; then
  echo "Usage: bash AutoTestService.sh <DeviceName>"
  echo "All other variables will need to be specified inside device specific image.conf file"
  exit 0
fi
#####################
#Initialize variables
#####################
now=$(date +"%Y%m%d%H%M%S")
devicefolder="$testroot/TestReports_$name"
testfolder="$devicefolder/$now"
source "$devicefolder/image.conf"
source "$thisdir/Functions.sh"

# Is the test type correct?
if ! get_config_param test_types $test > /dev/null ; then
  echo "No such test type $test defined in config" >&2
  exit 1
fi

########################################
#Checking if autotest is already running
########################################
autotestson=$(cat $devicefolder/autotestson.txt)
if [[ $autotestson == "yes" ]]; then
  exit 0
fi
#######################################################################################
#Non-continuous images (release, smoke, etc) are checked here
#######################################################################################
if [ "$(get_config_param test_types $test continuous)" != "True" ] ; then
  bash $scriptfolder/CheckZipQueue.sh $name
  if [[ $? != 0 ]]; then
    quit_clean 1
  fi
fi
############################################
#If we got this far, we can take control of autotestson.txt
############################################
echo yes > $devicefolder/autotestson.txt
##############################################
#Initializing variables and create test folder
##############################################
mkdir -p "$testfolder"
jiralog="$testfolder/$name-$now-jira_upload.log"
cronlog="$testfolder/$name-$now-cron.log"
##############################################
#Check that the device is on before proceeding
##############################################
echo "Starting autotest $now on device $name" >> $cronlog
bash $scriptfolder/Ping.sh $name >> $cronlog
if [[ $? != 0 ]]; then
  echo "SUT is offline. Lets wake it up" >> $cronlog
  if [[ $can == 1 ]]; then
    can_message "poweron"
    sleep 30
    bash $scriptfolder/Ping.sh $name >> $cronlog
    if [[ $? != 0 ]]; then
      echo "CAN message did not wake the device. Using tdtool for first poweron" >> $cronlog
      tdtool --on $switch >> $cronlog
    fi
  else
    tdtool --on $switch >> $cronlog
  fi
  sleep 30
  bash $scriptfolder/Ping.sh $name >> $cronlog
  if [[ $? != 0 ]]; then
    echo "SUT still not on. Error?" >> $cronlog
    quit_clean 1
  fi
fi
############################
#Check new updates and flash
############################
bash $scriptfolder/CheckZipQueue.sh $name >> $cronlog
if [[ $? == 0 ]]; then
  if [ "$(get_config_param test_types $test continuous)" == "True" ] ; then
    echo "Getting logs before flashing" >> $cronlog
    bash $scriptfolder/Sufuhandler.sh $name $now >> $cronlog
    if [[ $? != 0 ]]; then
    	echo "There was problem with sufu logs. Exiting" >> $cronlog
      quit_clean 1
    fi
    sleep 30
    python3 $jirafolder/boot_time_upload.py -n $name -t $now -y $test >> $jiralog
  fi
	bash $scriptfolder/RecoveryUpdate.sh $name >> $cronlog
	if [[ $? != 0 ]]; then
		echo "Error flashing new images" >> $cronlog
		quit_clean 1
	fi
fi
######################################################################
#Starting new test run. This also tests CAN wakeup before actual tests
######################################################################
echo "Starting new test set $test_plan on $name" >> $cronlog
bash $scriptfolder/Ping.sh $name >> $cronlog
if [[ $? != 0 ]]; then
	echo "Sut is offline." >> $cronlog
  if [[ $can == 1 ]]; then
    can_message "poweron"
  else
    tdtool --on $switch >> $crontab
  fi
  sleep 30
  bash $scriptfolder/Ping.sh $name >> $cronlog
  if [[ $? != 0 ]]; then
    echo "SUT still not on." >> $cronlog
    quit_clean 1
  fi
fi
###############################
#Now starts the actual autotest
###############################
echo "SUT is on. Starting test set" >> $cronlog
sleep 20
ssh-keygen -R $ip >> $cronlog
echo "Running concon.sh..." >> $cronlog
sshpass -p $ssh_pw ssh -o StrictHostKeyChecking=no root@$ip 'concon.sh' >> $cronlog
echo "Initiating plotfaster..." >> $cronlog
python3 $qatoolsfolder/plotfaster/execute_test.py -T $ip -i 10 -P $testfolder/ &
plotfaster_pid=$!
#################
#Run the test set
#################
echo "Running tests..." >> $cronlog
bash $scriptfolder/RunTestSet.sh $name $now >> $cronlog
if [[ $? != 0 ]]; then
  echo "There was an error running the test set" >> $cronlog
  quit_clean 1
fi
echo "Test set has been run" >> $cronlog
echo "Terminating plotfaster..." >> $cronlog
if [[ -d /proc/$plotfaster_pid ]];
then
  kill $plotfaster_pid
  wait $plotfaster_pid
else
  echo "Unable to send SIGTERM to plotfaster $plotfaster_pid" >> $cronlog
fi
#######################################################
#If the test is Release smoke test, then we do sufu now
#######################################################
if [ "$(get_config_param test_types $test sufu)" == "True" ] ; then
  bash $scriptfolder/Sufuhandler.sh $name $now >> $cronlog
  if [[ $? != 0 ]]; then
    echo "There was problem with sufu logs. Exiting" >> $cronlog
    quit_clean 1
  fi
  python3 $jirafolder/boot_time_upload.py -n $name -t $now -y $test >> $jiralog
  sleep 30
fi
#####################################################################
#Jira upload and slack announce depending if the test is smoke or not
#####################################################################
echo "Jira upload..." >> $cronlog
if [ "$(get_config_param test_types $test slack_announce)" == "True" ] ; then
  python3 $jirafolder/upload.py -n $name -t $now >> $jiralog
  python3 $slackfolder/slackbot.py $name $now >> $cronlog
elif [ "$(get_config_param test_types $test sufu)" == "True" ]; then
  python3 $jirafolder/upload.py -n $name -t $now >> $jiralog
else
  python3 $jirafolder/compare_and_upload_master.py -n $name -t $now >> $jiralog
fi
sleep 10
echo "Test set finished. Turning off" >> $cronlog
########################################################
#Last check that the CAN message can turn the device off
########################################################
if [[ $can == 1 ]]; then
  can_message "poweroff"
else
  tdtool --off $switch >> $cronlog
fi
sleep 30
bash $scriptfolder/Ping.sh $name >> $cronlog
if [[ $? == 0 ]]; then
	echo "Sut is on. Did not poweroff. Error." >> $cronlog
	quit_clean 1
fi
echo "Tests finished" >> $cronlog
quit_clean 0

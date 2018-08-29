#!/bin/bash
# Master Script to Check for New Image, Flash and Run Current Test v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

TESTRUNFLAG="${autotest_root}/c4c-functional-tests/TestReports_$1/TestRunOn"

if [ -f "${TESTRUNFLAG}" ]
then
  printf "Test run already in progress\n"
  exit 1
fi

> "${autotest_root}/c4c-functional-tests/TestReports_$1/TestRunOn"

# Run Git Updater
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Update_Tools_Tests.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "Git update error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "Git update OK\n"
fi

# Run Image Checker
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Host_Check_New_Image.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "No image to flash - exiting\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "Image available - proceeding to flash\n"
fi

# Make sure device has power before flashing
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Autotest_Power_On.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "SUT power on error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "SUT power on OK\n"
fi

# Sleep to allow boot to complete
sleep 30

IMAGEURL=$(cat "${autotest_root}/c4c-functional-tests/TestReports_$1/ImageToFlash.txt")
printf "$IMAGEURL\n"
IMAGEFILENAME=${IMAGEURL##*/}
printf "$IMAGEFILENAME\n"

# Download image from the URL in the file and verify
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/SUT_Download_Image.sh" $1 $2 $IMAGEURL $IMAGEFILENAME 
if [ ! $? -eq 0 ]
then
  printf "Download error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "Download OK\n"
fi

# Check Partition to use and set to file
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/SUT_Check_Partition.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "Partition check error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "Partition check OK\n"
fi

# Flash
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/SUT_Flash_Image.sh" $1 $2 $IMAGEFILENAME
if [ ! $? -eq 0 ]
then
  printf "Flashing error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "Flashing OK\n"
fi

# Set Boot script
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/SUT_Set_Bootscript.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "Bootscript error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "Bootscript OK\n"
fi

# Turn off SUT
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/SUT_Power_Off.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "SUT systemctl poweroff error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "SUT systemctl poweroff OK\n"
fi

# Sleep to allow system to power off cleanly
sleep 5

# Power cycle v2
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Autotest_Power_Off.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "SUT power off error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "SUT power off OK\n"
fi

# Sleep before power back on
sleep 30

bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Autotest_Power_On.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "SUT power on error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "SUT power on OK\n"
fi

# Sleep to allow boot to complete
sleep 30

# Remove SSH keys
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Host_Remove_Old_SSH_Key.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "SSH key removal error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "SSH key removal OK\n"
fi

sleep 30

# Add SSH keys
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Host_Add_New_SSH_Key.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "Adding SSH key error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "Adding SSH key OK\n"
fi

# Duplicate to pre-key adding sleep
sleep 30

# Collect device data from device before tests

bash "${autotest_root}/lm-autotest-utilities/autorun-tools/SUT_Collect_Device_Data.sh" $1 $2

# Fetch current test set from DAV, run current test set and upload results to DAV

bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Host_Run_Current_Test_Set.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "Test Run error\n"
  rm "${TESTRUNFLAG}"
  exit 1
else
  printf "Test Run OK\n"
fi

# Turn off SUT
# Shutdown
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/SUT_Power_Off.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "Final SUT systemctl poweroff error\n"
else
  printf "Final SUT systemctl poweroff OK\n"
fi

# Sleep to allow system to shutdown cleanly
sleep 5

# SUT Power Off
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Autotest_Power_Off.sh" $1 $2
if [ ! $? -eq 0 ]
then
  printf "Final SUT power off error\n"
else
  printf "Final SUT power off OK\n"
fi

latest_image_timestamp=$(head -1 "${autotest_root}/c4c-functional-tests/TestReports_$1/ImageToFlash_Timestamp.txt")
sed -i 's,^\(last_tested_image=\).*,\1'\"${latest_image_timestamp}\"',' "${autotest_root}/c4c-functional-tests/TestReports_$1/image.conf"

# Find the run's Test Results folder, run comparison and upload to DAV
bash "${autotest_root}/lm-autotest-utilities/autorun-tools/Host_Find_Test_Results.sh" $1 $2

rm "${TESTRUNFLAG}"
exit 0

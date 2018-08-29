#!/bin/bash
#########################################################
#
# Installs LM test data to LM Device or VM.
# Note: delete /tmp/lm-test-data if you want to re-download the data.
#
# Authors: Ville Ranki <ville.ranki@nomovok.com>
#
# License: Proprietary
# (C) 2016 Link Motion Oy
# All Rights reserved
#########################################################
function usage() {
	echo
	echo "USAGE: ./install_test_data.sh <target-ip> [target-port]"
	echo
}

TARGET_IP=$1
TARGET_PORT=$2

if [ -n "${TARGET_IP}" ]; then
    echo "Target ip ${TARGET_IP}"
else
	usage
    echo "ERROR: Please provide target ip as parameter"
    exit 1
fi

if [ -n "${TARGET_PORT}" ]; then
    echo "Target port ${TARGET_PORT}"
else
	TARGET_PORT=22
fi
echo "Setting up ${TARGET_IP}"

if [ ! -d "/tmp/lm-test-data" ]; then

echo -e "Please enter your DAV username (e-mail format): "
read USERNAME
if [ -n "${USERNAME}" ]; then
echo "Username: ${USERNAME}"
else
    echo "ERROR: username not given."
    exit 1
fi
echo "Downloading and decompressing test data.."
rm -rf /tmp/lm-test-data
mkdir -p /tmp/lm-test-data
pushd /tmp/lm-test-data

curl -u "${USERNAME}" "https://dav.nomovok.info/C4C/testing/automatedtesting/test_data/automated_nightly_music_files.zip" -o /tmp/lm-test-data/music.zip 
unzip music.zip
rm music.zip

echo "Test data extracted to /tmp/lm-test-data"
popd

else

echo "Test data already exists in /tmp/lm-test-data - uploading it."

fi # End if ! -d 

echo "Copying test data to target.."

scp -P ${TARGET_PORT} -r /tmp/lm-test-data/Music/* root@${TARGET_IP}:/home/user/Music/

echo "Test data copied to ${TARGET_IP}, all done"


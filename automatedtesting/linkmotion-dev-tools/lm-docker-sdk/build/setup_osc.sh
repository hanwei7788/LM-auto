#!/bin/bash
###############################################################################
#
# This script will configure the container OSC username and password.
# and will test them.
#
#
# License: Proprietary
# (C) 2016 Link Motion Oy
# All Rights Reserved
###############################################################################

function exit_on_failure() {
  set -e
}
function dont_exit_on_failure() {
  set +e
}

exit_on_failure

OSC_ARCH=$1

if [[ -z ${OSC_ARCH} ]]; then
  OSC_ARCH=imx6
fi

echo
echo "The docker container will need a valid osc username and password."
echo
read -p "Please enter your OBS username (short/shell format): " username
echo -n "Please enter your OBS password: "
read -s  password
echo
sed -i -- 's/__username__/'$username'/g' /root/.oscrc
sed -i -- 's/__password__/'$password'/g' /root/.oscrc
echo "The username and password has been written in plaintext to /root/.oscrc"
echo
echo "Testing the OSC connectivity (with the username and password which you provided).."
osc search lm-ivios --project -s | grep "^lm-ivios:[0-9.]*:${OSC_ARCH}"
echo "..tested."

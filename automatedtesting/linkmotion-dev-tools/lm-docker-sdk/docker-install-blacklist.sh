#!/bin/bash
#########################################################
#
# Setups ~/.linkmotion/blacklist/[PACKAGE] blacklist file
# for docker-install script.
#
# Author(s): Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#
# License: Proprietary
# (C) 2016 Link Motion Oy
# All Rights reserved
#########################################################

function exit_on_failure() {
  set -e
}
function dont_exit_on_failure() {
  set +e
}

exit_on_failure

function usage() {
  echo
  echo "./docker-install-blacklist.sh [package_name] [regexp_for_grep]"
  echo
  echo "The package_name should match a folder in your"
  echo "source path which is linked into docker container"
  echo "by default it is ~/src"
  echo 
  echo "The regexp_for_grep should be a valid regexp for 'grep'."
  echo
  echo " Example:"
  echo "   ./docker-install-blacklist.sh ui_center '\-b\-\|ui_center-cfg\|debug'"
  echo
}

function read_defaults_from_config() {
  CONFIG_PATH=${HOME}/.linkmotion/
  if [[ -d ${CONFIG_PATH} ]]; then
    if [[ -f ${CONFIG_PATH}/lm-docker-sdk.conf ]]; then
      if [[ -z ${CONTAINER_NAME} ]]; then
        CONTAINER_NAME=`cat ${CONFIG_PATH}/lm-docker-sdk.conf | tail -n+2`
      fi
      if [[ -z ${SRC_DIR} ]]; then
        SRC_DIR=`cat ${CONFIG_PATH}/lm-docker-sdk.conf | head -n1`
      fi
    fi
    if [[ -d ${CONFIG_PATH}/blacklist ]]; then
      if [[ -f ${CONFIG_PATH}/blacklist/${PACKAGE} ]]; then
        BLACKLISTED_PACKAGES=`cat ${CONFIG_PATH}/blacklist/${PACKAGE}`
      fi
    fi
  fi
}

# set work path to scriptpath
SCRIPTFILE=`realpath $0`
SCRIPTPATH=`dirname ${SCRIPTFILE}`
pushd ${SCRIPTPATH} > /dev/null

PACKAGE=$1
BLACKLIST=$2

if [[ -z ${PACKAGE} ]]; then
  usage
  echo "ERROR: 'package_name' is not defined"
  exit 1
fi

if [[ -z ${BLACKLIST} ]]; then
  usage
  echo "ERROR: 'regexp_for_grep' is not defined"
  exit 2
fi

read_defaults_from_config

echo
echo "Current blacklist for ${PACKAGE}:"
echo " ${BLACKLISTED_PACKAGES}"
echo
echo "You are changing it to:"
echo " ${BLACKLIST}"
echo
echo "press <enter> to confirm, or ctrl+c to cancel."
read

mkdir -p ${HOME}/.linkmotion/blacklist/
echo ${BLACKLIST} > ${HOME}/.linkmotion/blacklist/${PACKAGE}

echo "..updated."
popd > /dev/null

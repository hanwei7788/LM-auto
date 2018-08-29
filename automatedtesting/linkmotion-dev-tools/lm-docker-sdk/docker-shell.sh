#!/bin/bash
#########################################################
#
# A helper to access docker shell
#
# Authors: Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
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
  echo "./docker-shell.sh [container_name (optional)]"
  echo
  echo " Example:"
  echo "   ./docker-shell.sh lm-sdk"
  echo
}

function read_defaults_from_config() {
  CONFIG_PATH=/home/${USER}/.linkmotion/
  if [[ -d ${CONFIG_PATH} ]]; then
    if [[ -f ${CONFIG_PATH}/lm-docker-sdk.conf ]]; then
      if [[ -z ${CONTAINER_NAME} ]]; then
        CONTAINER_NAME=`cat ${CONFIG_PATH}/lm-docker-sdk.conf | tail -n+2`
        echo "Default value (${CONTAINER_NAME}) for container read from config."
      fi
      if [[ -z ${SRC_DIR} ]]; then
        SRC_DIR=`cat ${CONFIG_PATH}/lm-docker-sdk.conf | head -n1`
        echo "Default value (${SRC_DIR}) for source path read from config."
      fi
    fi
  fi
}

# set work path to scriptpath
SCRIPTFILE=`realpath $0`
SCRIPTPATH=`dirname ${SCRIPTFILE}`
pushd ${SCRIPTPATH} > /dev/null

###
# Arguments
CONTAINER_NAME=$1

read_defaults_from_config

###
# if container name was not defined, use default
if [[ -z ${CONTAINER_NAME} ]]; then
  CONTAINER_NAME=lm-sdk
fi

###
# start the docker container for building
docker start ${CONTAINER_NAME} > /dev/null

echo
echo "Replace 'lm-ivios:0.14:imx6','lm-ui-plugins','lm-ui-plugins-1.0.52' when applicaple."
echo
echo "In order to access the buildroot of your project follow steps:"
echo " 1) cd /lm-ivios:0.14:imx6/lm-ui-plugins"
echo " 2) osc chroot armv8el"
echo " 3) sb2"
echo " 4) cd /home/abuild/rpmbuild/BUILD/lm-ui-plugins-1.0.52"
echo

docker exec -it ${CONTAINER_NAME} bash

popd > /dev/null

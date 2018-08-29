#!/bin/bash
#########################################################
#
# Created docker image and container
#
# Authors: Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#          Ville Ranki <ville.ranki@nomovok.com>
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
	echo "./docker-create-container [container_name (optional)] [source_path (optional)]"
	echo
}

# set work path to scriptpath
SCRIPTFILE=`realpath $0`
SCRIPTPATH=`dirname ${SCRIPTFILE}`
pushd ${SCRIPTPATH} > /dev/null

###
# Arguments
CONTAINER_NAME=$1
SOURCE_PATH=$2
OSC_ARCH=$3

if [[ -z ${OSC_ARCH} ]]; then
  OSC_ARCH=imx6
fi

###
# if source path has not been set, use default
if [[ -z ${SOURCE_PATH} ]]; then
	SOURCE_PATH=/home/${USER}/src
fi

if [[ -z $2 ]]; then
	echo
	echo "Your host machine and the docker container needs to"
	echo "share a path for the source code."
	echo
	echo "We kindly ask you to either approve the default path"
	echo "or to enter a custom location where the main"
	echo "directory of your source code is."
	echo
	echo "The default location is ${SOURCE_PATH}."
	echo
	echo "Please note! You will have to make sure that you"
	echo "             place the source code to this location."
	echo
	echo -n "Is the default location good for you? (Y/n)"
	read ANSWER
	if [[ "${ANSWER}" == "n" ]]; then
		echo
		echo "Where is your source code?"
		read SOURCE_PATH
		SOURCE_PATH=`echo ${SOURCE_PATH}|sed -e "s/\~/\/home\/${USER}/g"`
		echo
	fi
fi

###
# if container name has not been set, use default
if [[ -z ${CONTAINER_NAME} ]]; then
	CONTAINER_NAME=lm-sdk
fi

###
# Store the default values in the home folder of the user
mkdir -p /home/${USER}/.linkmotion
CONF_FILE=/home/${USER}/.linkmotion/lm-docker-sdk.conf
echo ${SOURCE_PATH} > ${CONF_FILE}
echo ${CONTAINER_NAME} >> ${CONF_FILE}

###
# create source path if it does not exist
echo
echo "Preparing source path (${SOURCE_PATH}).."
mkdir -p ${SOURCE_PATH}
echo "..done!"
echo
echo "You should place your source code into:"
echo ${SOURCE_PATH}
echo
echo "Deleting old container if it exists.."
docker rm -f ${CONTAINER_NAME} || true
echo
echo "Building docker image.."
docker build -t ${CONTAINER_NAME}-image build
echo "..docker image built!"
echo
echo "Starting the docker container.."
docker run -itd -v ${SOURCE_PATH}:/opt/src --name ${CONTAINER_NAME} ${CONTAINER_NAME}-image bash
echo "..started!"
echo
echo "Running OSC setup.."
docker exec -it ${CONTAINER_NAME} /root/setup_osc.sh ${OSC_ARCH}
echo "..done!"
echo

popd > /dev/null

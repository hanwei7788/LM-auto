#!/bin/bash
#########################################################
#
# Builds and installs a package to device over ip.
#
# Authors: Ville Ranki <ville.ranki@nomovok.com>
#          Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#
# License: Proprietary
# (C) 2016 Link Motion Oy
# All Rights reserved
#########################################################

function usage() {
  echo
  echo "./docker-install.sh [package_name] [target_ip] [target_port (optional)] [container_name (optional)] [project (optional)] [srcdir (optional)] [outputdir (optional)]"
  echo
  echo "The package_name should match a folder in your"
  echo "source path which is linked into docker container"
  echo "by default it is ~/src"
  echo
  echo " Example:"
  echo "   ./docker-install.sh ui_center 127.0.0.1 5555 lm-sdk C4C:0.13:imx6"
  echo
}

# set work path to scriptpath
SCRIPTFILE=`realpath $0`
SCRIPTPATH=`dirname ${SCRIPTFILE}`
pushd ${SCRIPTPATH} > /dev/null
source ../scripts/common-functions.sh

exit_on_failure

###
# Arguments
PACKAGE=$1
TARGET_IP=$2
TARGET_PORT=$3
CONTAINER_NAME=$4
PROJECT=$5
SRC_DIR=$6
OUTPUTDIR=$7

BLACKLISTED_PACKAGES=$8

read_defaults_from_config

set_src_dir

set_container_name

SDK_PREFERRED_PKGS=${SRC_DIR}/lm-sdk-preferred-pkgs

check_package_name

###
# Check that target ip has been set, fail if otherwise
if [ -n "${TARGET_IP}" ]; then
    echo "Target ip ${TARGET_IP}"
else
    echo "ERROR: Please set target ip as 2nd param"
    usage
    exit 1
fi

###
# if target machine port is not defined, use default
if [ -z ${TARGET_PORT} ]; then
   TARGET_PORT=22
fi

###
# Check that the target machine is up
if ping -c 1 ${TARGET_IP} &> /dev/null
then
  echo "${TARGET_IP} is up, continuing.."
else
  echo "${TARGET_IP} is not reachable. Check ip and device."
  exit 1
fi

###
# Detect device reponame
REPONAME=lm-`ssh -p ${TARGET_PORT} root@${TARGET_IP} "cat /etc/issue | grep -wo '[0-9\.]*'|head -n1"`
DEVICE_ARCH=`ssh -p ${TARGET_PORT} root@${TARGET_IP} "uname -p"`

if [[ ${DEVICE_ARCH} == "i686" ]]; then
  OSC_ARCH=vm
else
  OSC_ARCH=imx6
fi

set_output_dir

###
# Show a summary of properties used
echo "docker-install.sh triggering docker build.."
echo " Package: ${PACKAGE}"
echo " Installation blacklist: ${BLACKLISTED_PACKAGES}"
echo " Container Name: ${CONTAINER_NAME}"
echo " Project: ${PROJECT}"
echo " Source Path: ${SRC_DIR}"
echo " Output dir: ${OUTPUTDIR}"
echo " SDK preferred pkg @ ${SDK_PREFERRED_PKGS}:"
ls ${SDK_PREFERRED_PKGS}/*.rpm 2> /dev/null || true

echo "Detected from target device:"
echo " Repo name is ${REPONAME}"
echo " Device architecture is ${DEVICE_ARCH}"
echo " OSC Architecture is ${OSC_ARCH}."
REPONAME_VERSION=`echo ${REPONAME}|sed "s/lm-//"`
PROJECT_FALLBACK="lm-ivios:${REPONAME_VERSION}:${OSC_ARCH}"

if [[ -z ${PROJECT} ]]; then
  # detect osc project
  dont_exit_on_failure
  echo "Auto detecting project.."
  PROJECT=`docker exec ${CONTAINER_NAME} osc search lm-ivios --project -s -a OBS:VeryImportantProject | grep "^lm-ivios:[0-9.]*:${OSC_ARCH}"`
  RETVAL=$?
  exit_on_failure
  if [[ ${RETVAL}=1 ]]; then
    PROJECT=${PROJECT_FALLBACK}
    echo "..unable to autodetect. using fallback ${PROJECT}."
  else
    echo "..autodetected ${PROJECT}."
  fi
fi

###
# Build the package
./docker-build.sh ${PACKAGE} ${CONTAINER_NAME} ${SRC_DIR} ${OUTPUTDIR} ${PROJECT} ${REPONAME} ${OSC_ARCH}
echo "..build complete!"
echo

###
# Install packages to the device
###
PACKAGES=`ls ${OUTPUTDIR}/*.rpm 2> /dev/null || true`
PREINSTALL_PACKAGES=`ls ${SDK_PREFERRED_PKGS}/*.rpm 2> /dev/null || true`

function install_packages() {
  for RPM_FILENAME in $@; do
    ./device-install-rpm.sh ${RPM_FILENAME} ${TARGET_IP} ${TARGET_PORT}
  done
}

function copy_to_localtmp() {
  FILES=$@
  mkdir -p /tmp/lm-docker-sdk/${PACKAGE}
  rm -Rf /tmp/lm-docker-sdk/${PACKAGE}/*
  for RPM_FILENAME in ${FILES}; do
   cp ${RPM_FILENAME} /tmp/lm-docker-sdk/${PACKAGE}
  done
}

function clean_localtmp() {
  rm -Rf /tmp/lm-docker-sdk
}

function install_all_packages_from_localtmp() {
  install_packages /tmp/lm-docker-sdk/${PACKAGE}/*.rpm
}

if [[ -z ${PACKAGES} ]]; then
  echo "ERROR: No packages were found."
  exit 1
fi

if [[ ! -z ${PREINSTALL_PACKAGES} ]]; then
  echo "Installing preinstall packages.."
  copy_to_localtmp ${PREINSTALL_PACKAGES}
  install_all_packages_from_localtmp
  echo
fi

echo "Installing built packages.."
copy_to_localtmp ${PACKAGES}
install_all_packages_from_localtmp
echo "..built packages installed!"

clean_localtmp

echo "RPMs have been installed to ${TARGET_IP}"

if [[ "${PACKAGE}"="ui_center" ]]; then
  ./device-restart-ui_center.sh ${TARGET_IP} ${TARGET_PORT}
fi

popd > /dev/null

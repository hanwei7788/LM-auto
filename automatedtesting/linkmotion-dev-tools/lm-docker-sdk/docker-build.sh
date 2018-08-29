#!/bin/bash
#########################################################
#
# Builds a package.
#
# Authors: Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#          Ville Ranki <ville.ranki@nomovok.com>
#
# License: Proprietary
# (C) 2016 Link Motion Oy
# All Rights reserved
#########################################################


function usage() {
  echo
  echo "./docker-build.sh [package_name] [container_name (optional)] [src_dir (optiona)] <outputdir> [project (optional)] [reponame (optional)] [arch (optional)]"
  echo
  echo "The package_name should match a folder in your"
  echo "source path which is linked into docker container"
  echo "by default it is ~/src"
  echo
  echo " Example:"
  echo "   ./docker-build.sh ui_center lm-sdk C4C:0.13:imx6"
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
CONTAINER_NAME=$2
SRC_DIR=$3
OUTPUTDIR=$4
PROJECT=$5
REPONAME=$6
OSC_ARCH=$7

ORIG_OUTPUTDIR=$OUTPUTDIR

read_defaults_from_config

if [[ -z ${REPONAME} ]]; then
  REPONAME=${REPONAME_FALLBACK}
fi

if [[ -z ${OSC_ARCH} ]]; then
  if [[ -z ${DOCKER_ARCH} ]]; then
    OSC_ARCH=imx6
  else
    OSC_ARCH=${DOCKER_ARCH}
  fi
fi

set_src_dir
set_container_name
set_output_dir
set_project
set_reponame
check_package_name

###
# prepare outputdir
echo "Cleaning the build (${OUTPUTDIR}) directory.."

###
# Make sure that the outputdir is not '/' as we have rm -rf ${OUTPUTDIR} later on..
if [[ "${OUTPUTDIR}" = "/" ]]; then
   echo "CRITICAL FAILURE: Output directory was set to '/'"
   exit 3
fi

rm -rf ${OUTPUTDIR}

###
# Show summary
echo "$0 starting build."
echo " Source code: ${SRC_DIR}"
echo " Output directory: ${OUTPUTDIR}"
echo " Package: ${PACKAGE}"
echo " Container name: ${CONTAINER_NAME}"
echo " Project: ${PROJECT}"
echo " Repo name: ${REPONAME}"
echo

###
# Make sure that the outputdir is set, as we have rm -rf ${OUTPUTDIR} later on..
#if [[ -z ${ORIG_OUTPUTDIR} ]]; then
#   read -p "Is it ok to delete everything in $OUTPUTDIR? [y/n] " -n 1 -r
#   echo
#   if [[ $REPLY =~ ^[Nn]$ ]]
#   then
#       exit 3
#   fi
#fi

check_source_path_exists
clean_source_path
start_container

###
# Show a summary and build package.
echo "Building ${OSC_ARCH} package for ${PACKAGE} inside the container ${CONTAINER_NAME}.."
echo " Container Name: ${CONTAINER_NAME}"
echo " Package: ${PACKAGE}"
echo " Project: ${PROJECT}"
echo " Reponame: ${REPONAME}"
docker exec ${CONTAINER_NAME} /root/oscbuild.sh "${PACKAGE}" "${PROJECT}" "${REPONAME}" "${OSC_ARCH}"
docker stop ${CONTAINER_NAME}
echo "..package build process finished."

###
# Check that the outputdir exists..
if [ ! -d ${OUTPUTDIR} ]
then
	echo "ERROR: Output not created in ${OUTPUTDIR} - build failed."
	exit 4
fi

###
# Count the packages which were built.. and if there was 0 then fail the build.
echo
PACKAGE_COUNT=`ls -la ${OUTPUTDIR}/*.rpm | wc -l`

if [[ "${PACKAGE_COUNT}" == "0" ]]; then
	echo "ERROR: Failed to build packages.. check build log."
	exit 5
else
  echo "${PACKAGE_COUNT} packages built in ${OUTPUTDIR}"
  PACKAGES=`ls ${OUTPUTDIR}/*.rpm 2> /dev/null || true`
# Delete the blacklisted packages from output if blacklist in use
  if [[ ! -z ${BLACKLISTED_PACKAGES} ]]; then
    PACKAGES_TO_DELETE=`ls ${OUTPUTDIR}/*.rpm|grep ${BLACKLISTED_PACKAGES} || true`
    echo "Deleting blacklisted packages (blacklist is ${BLACKLISTED_PACKAGES}):"
    for DELPACKAGE in ${PACKAGES_TO_DELETE}; do
      echo ${DELPACKAGE}
      rm ${DELPACKAGE}
    done
  fi
fi

popd > /dev/null

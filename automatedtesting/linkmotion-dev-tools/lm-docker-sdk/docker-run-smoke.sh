#!/bin/bash
#
# Runs smoke tests for a package.
#
# This script is WIP, do not use yet. -VR


function usage() {
  echo
  echo "./docker-run-smoke.sh [package_name] [src_dir (optiona)]"
  echo
  echo "The package_name should match a folder in your"
  echo "source path which is linked into docker container"
  echo "by default it is ~/src"
  echo
  echo " Example:"
  echo "   ./docker-run-smoke.sh ui_center"
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
SRC_DIR=$3

read_defaults_from_config
set_src_dir
set_container_name
check_package_name

###
# Show summary
echo "$0 starting build."
echo " Source code: ${SRC_DIR}"
echo " Package: ${PACKAGE}"
echo

check_source_path_exists
clean_source_path
start_container

###
# Show a summary and build package.
echo "Running smoke tests for ${PACKAGE} inside the container ${CONTAINER_NAME}.."
echo " Container Name: ${CONTAINER_NAME}"
echo " Package: ${PACKAGE}"
#docker exec ${CONTAINER_NAME} /root/oscbuild.sh "${PACKAGE}" "${PROJECT}" "${REPONAME}" "${OSC_ARCH}"
echo "..smoke test process finished."

popd > /dev/null

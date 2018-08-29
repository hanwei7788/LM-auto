# These are common function used in various shell scripts
# 
# If you detect copy-paste, move the code here instead.


IVIROOTFS=/usr/lib/lm_containers/ivi/rootfs

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

function exit_on_failure() {
  set -e
}
function dont_exit_on_failure() {
  set +e
}

function read_spec_file() {
  SPEC_FILE=$(find $SRCDIR/$PACKAGE/ -maxdepth 1 -type f -name "*.spec")
  if [ -z $SPEC_FILE ]
  then
      echo " -> spec file not found in $SRCDIR/$PACKAGE/"
      SPEC_FILE=$(find $SRCDIR/$PACKAGE/skytree/ -maxdepth 1 -type f -name "*.spec")
      if [ -z $SPEC_FILE ]
      then
          echo " -> spec file not found in $SRCDIR/$PACKAGE/skytree/"
          SPEC_FILE=$(find $SRCDIR/$PACKAGE/rpm/ -maxdepth 1 -type f -name "*.spec")
          if [ -z $SPEC_FILE ]
          then
              echo " -> spec file not found in $SRCDIR/$PACKAGE/rpm/"
              echo " -> Could not found spec file, exit"
              exit 1
          fi
      fi
  fi
  if [ -z $SPEC_FILE ]
      then
      echo " -> Can't find .spec file anywhere in $SRCDIR/$PACKAGE/"
      exit 1
  fi
  SPEC_PATH=$(dirname "$SPEC_FILE")

  # actual name that $PACKAGE will provide
  PACKAGENAME=$(cat $SPEC_FILE |grep Name | sed -n 's/Name://p'| sed -e 's/^[ \t]*//')
  VERSION=$(cat $SPEC_FILE |grep Version | sed -n 's/Version://p'| sed -e 's/^[ \t]*//')
  TARBALL=$(grep Source0 $SPEC_FILE | sed -n "s/Source0://p" | sed "s|%{name}|$PACKAGENAME|" | sed "s|%{version}|$VERSION|")
}

# sets SRC_DIR env variable
function set_src_dir() {
###
# if source path was not defined, use default
if [[ -z ${SRC_DIR} ]]; then
  # This is the same path as given parameter to docker run when starting container.
  # Modify if needed:
  SRC_DIR=/home/${USER}/src
fi
}

function set_container_name() {
###
# if container name was not defined, use default
if [[ -z ${CONTAINER_NAME} ]]; then
  CONTAINER_NAME=lm-sdk
fi
}

function set_output_dir() {
###
# if output path was not defined, use default
if [[ -z ${OUTPUTDIR} ]]; then
  OUTPUTDIR=${SRC_DIR}/build-${PACKAGE}-${OSC_ARCH}
fi
}

function set_project() {
###
# if output path was not defined, use default
if [[ -z ${PROJECT} ]]; then
# TODO: could this be read from somewhere?
  PROJECT="lm-common:0.34:imx6"
fi
}

function set_reponame() {
###
# if output path was not defined, use default
if [[ -z ${REPONAME} ]]; then
# TODO: could this be read from somewhere?
  REPONAME="lm-0.34"
fi
}

function check_package_name() {
###
# if package name was not defined, show an error and usage.
if [ -n "${PACKAGE}" ]; then
    echo "Package name ${PACKAGE}"
else
    echo "ERROR: Please set package name as 1st param"
    usage
    exit 1
fi
}

function check_source_path_exists() {
###
# Check that source code path exists
if [[ ! -d ${SRC_DIR}/${PACKAGE} ]]; then
  echo "ERROR: Source code is not available at ${SRC_DIR}/${PACKAGE}"
  exit 4
fi
}

function clean_source_path() {
###
# Prepare the source code tree, run make clean and distclean..
echo -n "Cleaning source directory (${SRC_DIR}/${PACKAGE}) before build.."
pushd ${SRC_DIR}/${PACKAGE} > /dev/null
dont_exit_on_failure
make clean 2> /dev/null 
make distclean 2> /dev/null
exit_on_failure
popd > /dev/null
echo 
}

function start_container() {
###
# start the docker container for building
docker start ${CONTAINER_NAME}
echo
}


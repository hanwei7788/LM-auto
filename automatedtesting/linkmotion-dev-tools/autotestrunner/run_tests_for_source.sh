#/bin/bash
. $(dirname "$0")/common.sh

SRC_DIR=$1

if [ -z ${SRC_DIR} ] ; then
  echo "Usage: ./run_tests_for_source.sh <source path>"
  exit -1
fi

${SCRIPTPATH}/create_container.sh
lxc-stop --name=${CONTAINER_NAME} -P${CONTAINER_PATH} -k
echo Restoring container to original state..
lxc-snapshot --name=${CONTAINER_NAME} -P${CONTAINER_PATH} -r snap0
cp /var/lib/lm-sdk/${USER}/containers/config-lm  /var/lib/lm-sdk/${USER}/containers/${CONTAINER_NAME}/
lxc-start --name=${CONTAINER_NAME} -P${CONTAINER_PATH}

if "/opt/lm-sdk/lm-sdk-ide/bin/lmsdk-target exists autotest" ; then 
  echo "Container doesn't exist - won't continue running tests"
  exit -1
fi

/opt/lm-sdk/lm-sdk-ide/bin/lmsdk-target rpmbuild ${CONTAINER_NAME} ${SRC_DIR} --build-deps --install

./run_ui_center_in_container.sh


#/bin/bash
. $(dirname "$0")/common.sh
lxc-stop -n ${CONTAINER_NAME} -P${CONTAINER_PATH}
lxc-destroy -f -s -n ${CONTAINER_NAME} -P${CONTAINER_PATH} || echo "Container ${CONTAINER_NAME} doesn't exist, can't destroy it."


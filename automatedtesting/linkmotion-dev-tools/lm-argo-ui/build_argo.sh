#!/bin/bash
CONTAINER_NAME=argo-ui
SOURCE_PATH=/home/${USER}/src

echo "Source path is ${SOURCE_PATH}"
echo

if [ ! -d "${SOURCE_PATH}/nanopb" ]; then
        echo nanopb not in source path, install it there
        exit -1
fi

if [ ! -d "${SOURCE_PATH}/ui_center" ]; then
        echo ui_center not in source path, install it there
        exit -1
fi


if [ ! -d "${SOURCE_PATH}/lmmw-ivi-entertain-plugin" ]; then
        echo lmmw-ivi-entertain-plugin not in source path, install it there
        exit -1
fi

echo -n "Is the default location good for you? (Y/n)"
read ANSWER
if [[ "${ANSWER}" == "n" ]]; then
        echo
        echo "Where is your source code?"
        read SOURCE_PATH
        SOURCE_PATH=`echo ${SOURCE_PATH}|sed -e "s/\~/\/home\/${USER}/g"`
        echo
fi

echo
echo Removing old container, if it exists..
docker rm -f ${CONTAINER_NAME} || true
echo
echo Building container..
docker build -t ${CONTAINER_NAME}-image build
echo
echo Running container..
docker run -itd -v ${SOURCE_PATH}:/opt/src --name ${CONTAINER_NAME} ${CONTAINER_NAME}-image bash
echo
echo Running the build script..
docker exec -it ${CONTAINER_NAME} /root/build_argo_ui.sh
echo
echo All done! To enter the container for debug purposes, run:
echo
echo docker exec -it ${CONTAINER_NAME} bash
echo
echo The built debian packages are in ${SOURCE_PATH}/argo-ui-built-packages
echo


#/bin/bash
. $(dirname "$0")/common.sh


if ! /opt/lm-sdk/lm-sdk-ide/bin/lmsdk-target exists ${CONTAINER_NAME} ; then
    echo Target ${CONTAINER_NAME} doesnt exist, creating it..

    if [ -z $LM_USERNAME ] ; then
      echo "Error: Set LM_USERNAME and LM_PASSWORD for SDK target creation."
      exit -1
    fi

    /opt/lm-sdk/lm-sdk-ide/bin/lmsdk-target create \
    -d link-motion-ivios -a i686 -b i686 -v pallas-0.30 -n ${CONTAINER_NAME}
    lxc-attach -n ${CONTAINER_NAME} -P${CONTAINER_PATH} -- zypper ref
    lxc-attach -n ${CONTAINER_NAME} -P${CONTAINER_PATH} -- zypper -n up
    lxc-stop --name=${CONTAINER_NAME} -P${CONTAINER_PATH}
    lxc-snapshot --name=${CONTAINER_NAME} -P${CONTAINER_PATH}
    cp /var/lib/lm-sdk/${USER}/containers/${CONTAINER_NAME}/config-lm /var/lib/lm-sdk/${USER}/containers/
else
    echo Target ${CONTAINER_NAME} exists, reusing it.
fi


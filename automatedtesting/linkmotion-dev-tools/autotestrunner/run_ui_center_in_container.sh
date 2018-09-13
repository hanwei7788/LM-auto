#!/bin/bash
#
# WIP!
#
# sudo apt install xvfb weston

SCRIPTPATH=$(dirname "$0")/
. $SCRIPTPATH/common.sh
if ! /opt/lm-sdk/lm-sdk-ide/bin/lmsdk-target exists ${CONTAINER_NAME} ; then
    echo Container ${CONTAINER_NAME} doesnt exist, please run create_container.sh first!
fi

CONTAINER_ROOTFS=`/opt/lm-sdk/lm-sdk-ide/bin/lmsdk-target rootfs ${CONTAINER_NAME}`
CONTAINER_IP=`lxc-info --name=${CONTAINER_NAME} -P${CONTAINER_PATH} | grep IP: | tr -d ' ' | cut -f2 -d:`
XDG_RUNTIME_DIR=/tmp/lm-test-xdg

if [ -z ${CONTAINER_IP} ] ; then
  echo "Container not running?"
fi

echo Container rootfs is ${CONTAINER_ROOTFS} and IP ${CONTAINER_IP}
# Set target IP for the cutedriver container
pushd ${SCRIPTPATH}../lm-cutedriver
./change_target_ip.sh ${CONTAINER_IP}
popd

# Clean up run environment
rm -rf ${XDG_RUNTIME_DIR}
mkdir -p ${XDG_RUNTIME_DIR}
chmod 700 ${XDG_RUNTIME_DIR}
killall xvfb-run
killall Xvfb
killall weston
killall qttasserver

# Start qttasserver
lxc-attach -n ${CONTAINER_NAME} -P${CONTAINER_PATH} -- nohup qttasserver &
sleep 1s
pgrep qttasserver || (echo qttasserver not running! && exit -1 )

# Launch xvfb and weston

xvfb-run -s "-ac -screen 0 1024x768x24" weston -c/opt/lm-sdk/lm-sdk-ide/share/qtcreator/linkmotion/weston.ini &

# Launch ui_center
DISPLAY=:99
LIBGL_ALWAYS_SOFTWARE=1
sleep 1s
echo Starting ui_center..

# Start ui_center
lxc-attach -n ${CONTAINER_NAME} -P${CONTAINER_PATH} -- su system -c "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} QT_LOAD_TESTABILITY=1 /usr/apps/org.c4c.ui_center/bin/ui_center -platform wayland" &

# Wait for ui_center started (notification would be better)
sleep 1s
rm /tmp/xray_report.*

# Run tests
pushd ${SCRIPTPATH}../lm-cutedriver
./run_test.sh smoke |& tee /tmp/xray_report.txt
# Copy test report json
./cp_latest_report_to.sh /tmp/xray_report.json
popd

rm xray_report.*
mv /tmp/xray_report.* .

echo "Test run finished - cleaning up"
killall ui_center
killall xvfb-run
killall Xvfb
killall weston
echo
if [ ! -f xray_report.json ]; then
  echo
  echo No report file generated - test failed.
  echo 
  exit -2
fi
reset

echo
echo Test report is now in xray_report.json and xray_report.txt
echo
grep tests, xray_report.txt
echo

if grep "\"status\": \"FAIL\"" xray_report.json > /dev/null ; then
  echo "Test was considered FAILURE"
  echo
  exit -1
elif grep "\"status\": \"ABORTED\"" xray_report.json > /dev/null ; then
  echo "Test was considered FAILURE"
  echo
  exit -1
else 
  echo "Test was considered success."
  echo
  exit 0
fi


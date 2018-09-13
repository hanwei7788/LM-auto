#!/bin/bash

# this script is run inside container and does the actual building.


# Check that file (with wildcards ok) exist, exit if not
function checkdeb {
if stat --printf='' $1 2>/dev/null
then
    echo $1 found, assuming build was ok
else
    echo $1 not found - exiting
    exit -1
fi
}

apt update

cd /opt/src

rm -rf argo-ui-built-packages
rm -rf /tmp/argo-ui-built-packages

mkdir -p /tmp/argo-ui-built-packages

/root/build_and_install_deb.sh nanopb

checkdeb /tmp/argo-ui-built-packages/libnanopb*.deb

/root/build_and_install_deb.sh lmlsapi-client

checkdeb /tmp/argo-ui-built-packages/lmlsapi-client*.deb

/root/build_and_install_deb.sh lm-ui-plugins

checkdeb /tmp/argo-ui-built-packages/lm-ui-plugins*.deb

/root/build_and_install_deb.sh lmmw-ivi-entertain-plugin

checkdeb /tmp/argo-ui-built-packages/lmmw-ivi-entertain-plugin*.deb

/root/build_and_install_deb.sh ui_center-plugin

checkdeb /tmp/argo-ui-built-packages/ui-center-plugin*.deb

cp -Rv /tmp/argo-ui-built-packages /opt/src

# Build ui_center

# deps
apt -y install qml-module-qtquick-xmllistmodel libcmocka-dev libsystemd-dev qtmultimedia5-dev qtpositioning5-dev qttools5-dev-tools qtbase5-private-dev libudev-dev

# Copy sources
rsync -r --exclude=.git --exclude=.o /opt/src/ui_center /tmp
pushd /tmp/ui_center
# Config & make
qmake CONFIG+=dontcompileqml CONFIG+=nocompositor
make

popd


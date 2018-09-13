#!/bin/bash

#
# Builds and installs named package from source
# and installs its debian build dependencies also.
#
# Params: package name
#

PACKAGE=$1
echo
echo     Now building $PACKAGE...
rm -rf /tmp/$PACKAGE
rsync -r --exclude=.git --exclude=.o /opt/src/$PACKAGE /tmp
pushd /tmp
cd $PACKAGE
mk-build-deps

apt install -fy ./*-build-deps*.deb
debuild -us -uc -b
apt install -fy ../*.deb

if ls ../*.deb 1> /dev/null 2>&1; then
    echo "Packages build.."
else
    echo
    echo "Error building $PACKAGE - see error log above"
    echo
    exit -1
fi

mv ../*.deb ../argo-ui-built-packages
popd
echo     $PACKAGE built.
echo


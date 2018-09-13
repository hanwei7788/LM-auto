#!/bin/bash

# This script must be run in the sysroot SDK! (probably works
# also inside VM SDK..)
#
# This script takes a package name as argument and
# builds it to i586 or arm rpm package for sdk vm or device.
# This scripts rip some parts from build_i586_rpm.sh

# PACKAGE is the input arg source folder name in SRCDIR for script
# for ex: if i cloned ui_center to ~/src/ui_center then i just need to run script
# in ~/src like: 
#
#$ ./linkmotion-dev-tools/scripts/sysroot-build.sh ui_center 
#

# Note: Still WIP. 

PACKAGE=$1
SRCDIR=.
BUILDDIR=/usr/src/packages/SOURCES
#RPMDIR=/var/tmp/build-root/skytree58-i586/home/abuild/rpmbuild/RPMS/i586
SCRIPTSDIR=$(dirname "$BASH_SOURCE")
source $SCRIPTSDIR/common-functions.sh
#PREFER_PKGS_DIR=$SRCDIR/lm-sdk-preferred-pkgs

#sudo rm -rf $RPMDIR/*.rpm

read_spec_file

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
            exit 0;
        fi
    fi
fi

echo "==> Using spec file: $SPEC_FILE"
echo "    - package name: $PACKAGENAME"
echo "    - version name: $VERSION"
echo "    - tarball source: $TARBALL"

mkdir -p $BUILDDIR
cp $SPEC_PATH/*.spec $SPEC_PATH/*.patch $BUILDDIR  2> /dev/null


cd $SRCDIR
echo "==> Building $PACKAGENAME-$VERSION"

rm -rf /tmp/$PACKAGE 2> /dev/null
rm -rf /tmp/$PACKAGENAME-$VERSION 2> /dev/null
#/altdata/devel/bin/rsync -r --exclude=.git --exclude=Makefile,.gitignore $PACKAGE /tmp
cp -R $PACKAGE /tmp
cp $SPEC_FILE $BUILDDIR
mv /tmp/$PACKAGE /tmp/$PACKAGENAME-$VERSION

pushd /tmp
rm $TARBALL 2> /dev/null
echo "==> Compressing $PACKAGENAME"
tar caf $TARBALL $PACKAGENAME-$VERSION

mv $TARBALL $BUILDDIR/
popd

SPEC_FILENAME=`basename $SPEC_FILE`

pushd $BUILDDIR/
rpmbuild -bb $SPEC_FILENAME
popd


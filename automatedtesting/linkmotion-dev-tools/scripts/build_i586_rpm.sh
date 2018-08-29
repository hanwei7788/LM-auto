#!/bin/bash

#
# This script takes a package name as argument and
# builds it to i586 rpm package for sdk vm.
# This scripts rip some part from docker sdk oscbuild.sh

# PACKAGE is the input arg source folder name in SRCDIR for script
# for ex: if i cloned ui_center to ~/src/ui_center then i just need to run script
# like: ./build_i586_rpm.sh ui_center
PACKAGE=$1

# For easy to use, this /media/sf_src is automount dir the mount my host ~/src to /media/sf_src
# in sdk vm. So i only need to clonce code on Host machine 1 times and they are
# available to SDK vm automatically.
# i.e: with the example above ~/src/ui_center is mounted to /media/sf_src/ui_center
SRCDIR=/media/sf_src
BUILDDIR=/home/system/rpmbuild/SOURCES
RPMDIR=/var/tmp/build-root/skytree58-i586/home/abuild/rpmbuild/RPMS/i586
SCRIPTSDIR=$(dirname "$BASH_SOURCE")
source $SCRIPTSDIR/common-functions.sh
PREFER_PKGS_DIR=$SRCDIR/lm-sdk-preferred-pkgs

sudo rm -rf $RPMDIR/*.rpm

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

cp $SPEC_PATH/*.spec $SPEC_PATH/*.patch $BUILDDIR


cd $SRCDIR
echo "==> Building $PACKAGENAME-$VERSION"

rm -rf /tmp/$PACKAGE 2> /dev/null
rm -rf /tmp/$PACKAGENAME-$VERSION 2> /dev/null
/altdata/devel/bin/rsync -r --exclude=.git --exclude=Makefile,.gitignore $PACKAGE /tmp
mv /tmp/$PACKAGE /tmp/$PACKAGENAME-$VERSION

pushd /tmp
rm $TARBALL 2> /dev/null
echo "==> Compressing $PACKAGENAME"
tar caf $TARBALL $PACKAGENAME-$VERSION


mv $TARBALL $BUILDDIR/
cp $SPEC_FILE $BUILDDIR
popd

cd $BUILDDIR/
rpmbuild -bb $SPEC_FILE

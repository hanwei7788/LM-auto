#!/bin/bash

# This script takes a package name as argument and
# builds it to i586 rpm package inside sdk vm.
#
# PACKAGE is the input arg source folder name in SRCDIR for script
# for ex: if i cloned ui_center to ~/src/ui_center then i just need to run script
# like: ./vb-build-rpm.sh ui_center
#
# This script doesn't need any shared directory with SDK VM, all is
# handled using SSH.

PACKAGE=$1
SSH_OPTS="-p 5555"
SCP_OPTS="-P 5555"
BUILDDIR=/home/system/rpmbuild/SOURCES
SRCDIR=.

SCRIPTSDIR=$(dirname "$BASH_SOURCE")
source $SCRIPTSDIR/common-functions.sh

read_spec_file

echo "==> Using spec file: $SPEC_FILE"
echo "    - package name: $PACKAGENAME"
echo "    - version name: $VERSION"
echo "    - tarball source: $TARBALL"

cd $SRCDIR
echo "==> Collecting build files.."

rm -rf /tmp/$PACKAGE 2> /dev/null
rm -rf /tmp/$PACKAGENAME-$VERSION 2> /dev/null
rsync -r --exclude=.git --exclude=Makefile,.gitignore $PACKAGE /tmp
mv /tmp/$PACKAGE /tmp/$PACKAGENAME-$VERSION

pushd /tmp
rm $TARBALL 2> /dev/null
tar caf $TARBALL $PACKAGENAME-$VERSION

echo "==> Copying build files to VM.."

ssh $SSH_OPTS system@localhost mkdir -p /home/system/rpmbuild/SOURCES/
ssh $SSH_OPTS system@localhost mkdir -p /home/system/rpmbuild/RPMS/i586
ssh $SSH_OPTS system@localhost rm /home/system/rpmbuild/RPMS/i586/*
scp $SCP_OPTS $TARBALL system@localhost:rpmbuild/SOURCES/
popd
scp $SCP_OPTS $SPEC_FILE system@localhost:rpmbuild/SOURCES/

echo "==> Building $PACKAGENAME-$VERSION.."

ssh $SSH_OPTS -tt system@localhost << EOF
cd rpmbuild/SOURCES/
rpmbuild -ba $PACKAGE.spec
logout
EOF

read_defaults_from_config


echo "==> Installing result rpm's.."

if [[ ! -z ${BLACKLISTED_PACKAGES} ]]; then
  echo "Package blacklist '${BLACKLISTED_PACKAGES}' was defined. Filtering.."
  PACKAGES=`ssh $SSH_OPTS system@localhost ls /home/system/rpmbuild/RPMS/i586/*.rpm|grep -v ${BLACKLISTED_PACKAGES} || true`
else
  PACKAGES=`ssh $SSH_OPTS system@localhost ls /home/system/rpmbuild/RPMS/i586/*.rpm || true`
fi

for PACKAGE in ${PACKAGES}; do
  ssh $SSH_OPTS root@localhost rpm -Uvh --force $PACKAGE
done

echo "$PACKAGENAME-$VERSION should now be installed on SDK VM."


#!/bin/bash

#
# This script copies package's sources from current dir to
# virtual machine and compiles it there (for x86).
#
# You can set this as build command in QtC.
#
# Use vb-run.sh to run the build result.
#
# Note: this doesn't build rpm package, just builds binary.
#

SSH_OPTS="-p 5555"
PACKAGE=$1

# Build ui_center if no package defined
if [[ -z ${PACKAGE} ]]; then
  PACKAGE=ui_center
fi

rsync -e "ssh $SSH_OPTS" -avz --delete --rsync-path=/altdata/devel/bin/rsync $PACKAGE system@localhost:/home/system/src 

ssh $SSH_OPTS system@localhost << EOF
  cd /home/system/src/$PACKAGE
  qmake
  make $1
EOF


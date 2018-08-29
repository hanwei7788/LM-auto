#!/bin/bash
###############################################################################
#
# This script takes a package name as argument and
# builds it to arm rpm package.
#
# Note: this is run INSIDE the sdk container.
#
# USAGE:
#   ./oscbuild.sh [package_name] [project (optional)] [reponame (optional)]
#
# EXAMPLE:
#   ./oscbuild.sh ui_center
#
# License: Proprietary
# (C) 2016 Link Motion Oy
# All Rights Reserved
###############################################################################

function exit_on_failure() {
  set -e
}
function dont_exit_on_failure() {
  set +e
}

exit_on_failure

# PACKAGE is the input arg source folder name in SRCDIR for script
PACKAGE=$1

# optional
PROJECT=$2
# Change this when version is updated
PROJECT_FALLBACK=lm-common:0.34

# optional
REPONAME=$3

# optional
OSC_ARCH=$4

if [[ -z ${REPONAME} ]]; then
  # Change this when version is updated
  REPONAME=lm-0.34
fi

if [[ -z ${OSC_ARCH} ]]; then
  OSC_ARCH=imx6
fi

if [[ ! -f /root/.oscrc ]]; then
    echo "ERROR: /root/.oscrc does not exist. Please run setup_osc.sh script."
    exit 2
fi

# if PROJECT was not passed as an argument then use auto-detection
if [[ -z ${PROJECT} ]]; then
    dont_exit_on_failure
    echo "Autodetecting project.."
    PROJECT=$(osc search lm-common --project -s -a OBS:VeryImportantProject | grep "^lm-common:[0-9.]*:${OSC_ARCH}")
    echo "..${PROJECT} detected!"
    if [[ -z ${PROJECT} ]]; then
       PROJECT=${PROJECT_FALLBACK}:${OSC_ARCH}
       echo "..Unable to detect. Using fallback project value: ${PROJECT}"
    else
       echo "..${PROJECT} detected!"
    fi
    exit_on_failure
else
    echo "Using given project: ${PROJECT}"
fi

if [ -z ${PROJECT} ]; then
    echo "ERROR: Project was not detected! You will have to define it manually. Cancelled."
    exit 1
fi

if [[ ${OSC_ARCH} == "imx6" ]]; then
  ARCH=armv8el
else
  ARCH=i586
fi

SRCDIR=/opt/src
RPMDIR=/var/tmp/build-root/${REPONAME}-${ARCH}/home/abuild/rpmbuild/RPMS/
OUTPUTDIR=${SRCDIR}/build-${PACKAGE}-${OSC_ARCH}
PREFER_PKGS_DIR=${SRCDIR}/lm-sdk-preferred-pkgs

dont_exit_on_failure
SPEC_FILE=$(find ${SRCDIR}/${PACKAGE}/ -maxdepth 1 -type f -name "*.spec")
if [ -z ${SPEC_FILE} ]
then
    echo " -> spec file not found in ${SRCDIR}/${PACKAGE}/"
    SPEC_FILE=$(find ${SRCDIR}/${PACKAGE}/skytree/ -maxdepth 1 -type f -name "*.spec")
    if [ -z ${SPEC_FILE} ]
    then
        echo " -> spec file not found in ${SRCDIR}/${PACKAGE}/skytree/"
        SPEC_FILE=$(find ${SRCDIR}/${PACKAGE}/rpm/ -maxdepth 1 -type f -name "*.spec")
        if [ -z ${SPEC_FILE} ]
        then
            echo " -> spec file not found in ${SRCDIR}/${PACKAGE}/rpm/"
            echo " -> Could not found spec file, exit"
            exit 1;
        fi
    fi
fi
exit_on_failure
echo "==> Using spec file: ${SPEC_FILE}"

# actuall name that ${PACKAGE} will provide
PACKAGENAME=$(cat ${SPEC_FILE} |grep Name | sed -n 's/Name://p'| sed -e 's/^[ \t]*//')
echo "    - package name: ${PACKAGENAME}"
VERSION=$(cat ${SPEC_FILE} |grep Version | sed -n 's/Version://p'| sed -e 's/^[ \t]*//')
echo "    - version name: ${VERSION}"
TARBALL=$(grep Source0 ${SPEC_FILE} | sed -n "s/Source0://p" | sed "s|%{name}|${PACKAGENAME}|" | sed "s|%{version}|${VERSION}|")
echo "    - tarball source: ${TARBALL}"
OSCDIR=/${PROJECT}/${PACKAGENAME}

mkdir -p ${PREFER_PKGS_DIR}
find ${PREFER_PKGS_DIR} -type f -exec echo Prefer pkgs directory contains {} \;

echo "==> Checking out OSC dir"
rm -rf ${OSCDIR}
cd /
osc co ${PROJECT} ${PACKAGENAME}
rm -f ${OSCDIR}/*

rm -rf ${RPMDIR}/*

cd ${SRCDIR}

echo "==> Building ${PACKAGENAME}-${VERSION}"

rm -rf /tmp/${PACKAGE} 2> /dev/null
rm -rf /tmp/${PACKAGENAME}-${VERSION} 2> /dev/null
rsync -rv --exclude=.git --exclude=Makefile,.gitignore ${PACKAGE} /tmp
mv /tmp/${PACKAGE} /tmp/${PACKAGENAME}-${VERSION}
pushd /tmp
rm -f ${TARBALL} 2> /dev/null
echo "==> Compressing ${PACKAGENAME}"
tar caf ${TARBALL} ${PACKAGENAME}-${VERSION}


mv ${TARBALL} ${OSCDIR}
cp ${SPEC_FILE} ${OSCDIR}
popd

cd ${OSCDIR}
osc build --trust-all-projects --no-verify --no-service --prefer-pkgs=${PREFER_PKGS_DIR} ${REPONAME} ${ARCH}
mkdir -p ${OUTPUTDIR}
# Move all built rpm's to outputdir
find ${RPMDIR} -name *.rpm -exec mv {} ${OUTPUTDIR} \;
chmod -R a+rw ${OUTPUTDIR}
echo "==> RPMs built and copied to ${OUTPUTDIR} in container"


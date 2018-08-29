#!/bin/bash

if [ $# -lt 1 ]; then
    echo usage $0 '<sdk ova to convert>'
    exit 1
fi


sdk_vdi=$1

if [ ! -f ${sdk_vdi} ]
then
    echo " -> Could not find vdi file ${sdk_vdi}, exiting.."
    exit 1
fi


# Change container name here if needed:
contname=lm-lxc-sdk

if [[ -z ${contname} ]]; then
  contname=lm-lxc-sdk
fi

contdir=/var/lib/lxc/${contname}
image=sdk.raw

echo Installing dependencies if needed..
echo 

apt install lxc cgmanager virtualbox

echo 
echo "About to create container:"
echo " - From vdi file ${sdk_vdi}"
echo " - To container dir ${contdir} (will be deleted first)"
echo " - Container name ${contname}"
echo
echo -n "Continue? (Y/n)"
read ANSWER
if [[ "${ANSWER}" == "n" ]]; then
    exit 0
fi
echo 
echo Cleaning up old container..
echo
lxc-stop -n ${contname} -t 5 ||true
umount ${contdir}/rootfs ||true
rm -rf ${contdir} ||true
mkdir -p ${contdir}/rootfs
echo
echo Extracting .ova...
echo
tar xvf ${sdk_vdi} -C ${contdir}
echo

sdk_vmdk_file=`ls ${contdir} |grep disk1.vmdk`
if [[ -z ${sdk_vmdk_file} ]]; then
    echo "Unable to find *disk1.vmdk inside the .ova. Aborting."
    exit -1
fi
echo
echo Converting to raw disk image..
echo
VBoxManage clonehd ${contdir}/${sdk_vmdk_file} ${contdir}/${image} --format RAW
rm ${contdir}/*.vmdk ${contdir}/*.ovf
echo
echo Configuring..
echo 
cp config ${contdir}/
echo "lxc.rootfs = ${contdir}/rootfs" >> ${contdir}/config
echo
echo Mounting the rootfs..
# Container created to ${contdir}, to run, mount rootfs (need once):
mount -o loop,offset=512 ${contdir}/${image} ${contdir}/rootfs
echo
echo Starting container..
echo
# Run container in background
lxc-start -d -n ${contname}
echo Container ${contname} is now running.
echo
echo Use `tput bold`sudo lxc-attach -n lm-lxc-sdk`tput sgr0` to enter it. 
echo Root filesystem is mounted in ${contdir}/rootfs
echo ssh server running at port 22 of the container. Use lxc-ls --fancy to see IP.
echo



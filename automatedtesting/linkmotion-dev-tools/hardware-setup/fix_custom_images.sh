#!/bin/bash
#########################################################
#
# Helper script to download and customize the hw images
#
# Authors: Zoltan Balogh <zoltan.balogh@link-motion.com>
#
# License: Proprietary
# (C) 2017 Link Motion Oy
# All Rights reserved
#########################################################
VERBOSE=true
VERSION="0.23"
IMAGE_SERVER="https://dav.nomovok.info/argo/images/rnd/"
UDEV_RULE_TO_FIX="ACTION==\"add\", SUBSYSTEM==\"net\", ENV{ID_NET_NAME_MAC}==\"\
wlx\*\", RUN{program}=\"\/bin\/systemctl --no-block restart ivi-interface@wifi-\
%E{INTERFACE}\.service"
IMAGE_FILE=""
AUTOOS_IMAGE_FILE=""
IVIOS_IMAGE_FILE=""
IMAGE_MOUNT_POINT=""
DOWNLOAD_IMAGE=false
TEMPDIR="/tmp/"
DEVICE=""
DOWNLOAD_LATEST_IMAGE=false
PUBLIC_KEY=""
YES_TO_ALL=false
FIX_IMAGES=false

function echo(){
	if [[ $VERBOSE == true ]]; then
		builtin echo $@;
	fi
}

function confirm(){
	if [ $YES_TO_ALL == false ]; then
		# call with a prompt string or use a default
		read -r -p "${1:-Are you sure? [y/N]} " response
		case "$response" in
			[yY][eE][sS]|[yY])
				true
				;;
			*)
				false
				;;
		esac
	else
		true
	fi
}

function wait_for_correct_block_device(){
	# Waiting for a properly partitioned devices to be present
	CORRECT_PARTITONS=false
	while [ CORRECT_PARTITONS==false ]; do
		IFS=$'\r\n' GLOBIGNORE='*' command eval 'BLOCK_DEVICES=($(lsblk -d -e 11,1 -o NAME,SIZE,MODEL|grep -v "NAME   SIZE MODE"))'
		for BLOCK_DEVICE in "${BLOCK_DEVICES[@]}"
		do
			arr=($BLOCK_DEVICE)
			DEVICE=${arr[0]}
			IFS=$'\r\n' GLOBIGNORE='*' command eval 'PARTITIONS=($(lsblk -o KNAME,TYPE,SIZE,MODEL,LABEL /dev/$DEVICE|grep part))'
			if [ ${#PARTITIONS[@]} != 7 ];then
				continue
			fi
			for PARTITION in "${PARTITIONS[@]}"
			do
				PARTITION_NAME=`echo $PARTITION | awk '{print $1;}'`
				PARTITION_LABEL=`echo $PARTITION | awk '{print $4;}'`
				case ${PARTITION_NAME: -1} in

					"1")
						if [ "$PARTITION_LABEL" != SECBOOT ];then
							CORRECT_PARTITONS=false
							break
						fi
						;;
					 "2")
						if [ "$PARTITION_LABEL" != AUTOOS_RO ] && [ "$PARTITION_LABEL" != platform ];then
							CORRECT_PARTITONS=false
							break
						fi
						;;
					"3")
						if [ "$PARTITION_LABEL" != AUTOOS_RW ];then
							CORRECT_PARTITONS=false
							break
						fi
						;;
					"4")
						if [ "$PARTITION_LABEL" != IVIOS_RO ] && [ "$PARTITION_LABEL" != platform ];then
							CORRECT_PARTITONS=false
							break
						fi
						;;
					"5")
						if [ "$PARTITION_LABEL" != IVIOS_RW ];then
							CORRECT_PARTITONS=false
							break
						fi
						;;
					"6")
						if [ "$PARTITION_LABEL" != SECCONT_RO ];then
							CORRECT_PARTITONS=false
							break
						fi
						;;
					"7")
						if [ "$PARTITION_LABEL" != SECCONT_RW ];then
							CORRECT_PARTITONS=false
							break 
						else
							CORRECT_PARTITONS=true
							break 3
						fi
						;;

					*)
						CORRECT_PARTITONS=false
						break
					;;
				esac
			done
		done
		sleep 0.1
	done
}

function authentication(){
	if [ -f ~/.wgetrc ];then
		# using .wgetrc instead of the unsecure password parameter
		WGET_PARAMETER="--user ${LDAP_ID} --password ${PASSWORD}"
	else
		WGET_PARAMETER=""
	fi
	if [ -z "$LDAP_ID" ];then
		echo -n "Enter the LDAP user for the image server: "
		read LDAP_ID
	fi
	if [ -z "$PASSWORD" ];then
		echo -n "Password: "
		# save original terminal setting.
		STTY_ORIG=`stty -g`
		# turn-off echoing.
		stty -echo # turn-off echoing.
		read PASSWORD
		# restore terminal setting.
		stty $STTY_ORIG	# restore terminal setting.
		echo
	fi
	if [ -f ~/.wgetrc ];then
		WGET_PARAMETER=""
	else
		# using .wgetrc instead of the unsecure password parameter
		WGET_PARAMETER="--user ${LDAP_ID} --password ${PASSWORD}"
	fi
}

function download_image(){
	IMAGE_TYPE=$1
	PROMPT="Please select an image file to download:"
	STRING=`curl -s "${IMAGE_SERVER}imx6-${VERSION}-swa_${IMAGE_TYPE}-rnd/" --list-only -u ${LDAP_ID}:${PASSWORD}| \
		grep .ext4fs.xz|grep -v "sha1sum"| \
		sed "s/.*\(imx6-${VERSION}-swa_${IMAGE_TYPE}-rnd-.*-.*.ext4fs.xz\).*/\1/g"|sort -nr`
	set -f
	OPTIONS=(${STRING// / })
	PS3="$PROMPT "
	if [ $DOWNLOAD_LATEST_IMAGE == true ]; then
		IMAGE_FILE=${OPTIONS[0]}
	else
		set -f
		OPTIONS=(${STRING// / })
		PS3="$PROMPT "
		select opt in "${OPTIONS[@]}" "Quit" ; do
			if (( REPLY == 1 + ${#OPTIONS[@]} )) ; then
				exit
 			elif (( REPLY > 0 && REPLY <= ${#OPTIONS[@]} )) ; then
 				echo "You picked $opt which is file $REPLY"
				IMAGE_FILE=$opt
				break
			else
				echo "Invalid option. Try another one."
			fi
		done
	fi
	if [ ! -f ${IMAGE_FILE} ]; then
		wget ${WGET_PARAMETER} ${IMAGE_SERVER}imx6-${VERSION}-swa_${IMAGE_TYPE}-rnd/${IMAGE_FILE} -q --show-progress
	else
		echo the ${IMAGE_FILE} is already present
	fi
	if [ ! -f ${IMAGE_FILE}.sha1sum ]; then
		wget ${WGET_PARAMETER} ${IMAGE_SERVER}imx6-${VERSION}-swa_${IMAGE_TYPE}-rnd/${IMAGE_FILE}.sha1sum -q --show-progress
	else
		echo the ${IMAGE_FILE}.sha1sum is already present
	fi
	SHA1SUM=`sha1sum ${IMAGE_FILE} | awk '{ print $1 }'`
	SHA1SUM_SERVER=`cat ${IMAGE_FILE}.sha1sum|awk '{ print $1 }'`
	if [[ ${SHA1SUM} =~ ${SHA1SUM_SERVER=} ]]; then
		case $IMAGE_TYPE in
			"autoos")
				AUTOOS_IMAGE_FILE=$IMAGE_FILE
				;;
			"ivios")
				IVIOS_IMAGE_FILE=$IMAGE_FILE
				;;
			*)
				;;
		esac
	else
		echo The sha1sum did not match. It means that the download image got corrupted 
		echo or the ${IMAGE_FILE} is already a customized one. Exiting
		exit
	fi
}

function mount_image(){
	IMAGE_MOUNT_POINT=${IMAGE_FILE/.ext4fs.xz/}
	if [ -d ${TEMPDIR}/${IMAGE_MOUNT_POINT} ]; then
		echo "the ${TEMPDIR}/${IMAGE_MOUNT_POINT} exists"
		exit
	else
		if [ ! -z ${IMAGE_MOUNT_POINT} ] && [ ! -z ${TEMPDIR} ];then
			mkdir "${TEMPDIR}/${IMAGE_MOUNT_POINT}"
		fi
	fi
	echo Unpacking the ${IMAGE_FILE}
	unxz ${IMAGE_FILE}
	echo Mounting ${IMAGE_MOUNT_POINT}.ext4fs to ${TEMPDIR}/${IMAGE_MOUNT_POINT}
	sudo mount -t ext4 ${IMAGE_MOUNT_POINT}.ext4fs -o loop ${TEMPDIR}/${IMAGE_MOUNT_POINT}
}

function fix_wifi(){
	echo Fixing the udev rules
	if [ ! -z ${IMAGE_MOUNT_POINT} ] && [ ! -z ${TEMPDIR} ] && [ -d ${TEMPDIR}/${IMAGE_MOUNT_POINT} ];then
		sudo sed -i -- "s/\($UDEV_RULE_TO_FIX\)/#\1/g" ${TEMPDIR}/${IMAGE_MOUNT_POINT}/lib/udev/rules.d/90-container-devices.rules
	fi
}

function transfer_connman_settings(){
	echo Fixing the connman configuration
	if [ ! -z ${IMAGE_MOUNT_POINT} ] && [ ! -z ${TEMPDIR} ] && [ -f ${TEMPDIR}/${IMAGE_MOUNT_POINT}/etc/connman/main.conf ];then
		sudo sed -i -- 's/\(PreferredTechnologies=\)ethernet,\(wifi\),cellular/\1\2/' ${TEMPDIR}/${IMAGE_MOUNT_POINT}/etc/connman/main.conf
	else
		echo The ${TEMPDIR}/${IMAGE_MOUNT_POINT}/etc/connman/main.conf can not be modified
	fi

	if [ -f connman.tar.gz ];then
		echo Unpacking the connman.tar.gz to ${TEMPDIR}/${IMAGE_MOUNT_POINT}/var/lib/
		sudo tar -xzf connman.tar.gz -C ${TEMPDIR}/${IMAGE_MOUNT_POINT}/var/lib/
		echo Fixing the ownership of ${TEMPDIR}/${IMAGE_MOUNT_POINT}/var/lib/connman
		sudo chown root:root ${TEMPDIR}/${IMAGE_MOUNT_POINT}/var/lib/connman -R
	else
		echo "No connman configuration is available"
		echo "Set up manually the wifi connection on the hardware and"
		echo "back up the /var/lib/connman directory in a tar.gz format"
		echo "That connman configuration can be later reused for new images."
	fi
}

function transfer_ssh_key(){
	if [ -z "$PUBLIC_KEY" ]; then
		set +f
		PROMPT="Select public key to use for authentication"
		PUBLIC_KEYS=`ls -1 ~/.ssh/*.pub`
		set -f
		OPTIONS=(${PUBLIC_KEYS// / })
		PS3="$PROMPT "
		select opt in "${OPTIONS[@]}" "Create new" ; do
			if (( REPLY == 1 + ${#OPTIONS[@]} )) ; then
				echo Creating new ssh key
				echo -e 'y\n'|ssh-keygen -f ~/.ssh/ssh_${IMAGE_TYPE}_rsa_key -N '' -t rsa
				PUBLIC_KEY=~/.ssh/ssh_${IMAGE_TYPE}_rsa_key.pub
			elif (( REPLY > 0 && REPLY <= ${#OPTIONS[@]} )) ; then
				echo "The $opt will be added to the image"
				PUBLIC_KEY=$opt
				break
			else
				echo "Invalid option. Try another one."
			fi
		done
	fi
	echo "Copying the $PUBLIC_KEY to the image"
	if [ ! -z ${IMAGE_MOUNT_POINT} ] && [ ! -z ${TEMPDIR} ] && [ -d ${TEMPDIR}/${IMAGE_MOUNT_POINT} ];then
		sudo mkdir -p "${TEMPDIR}/${IMAGE_MOUNT_POINT}/etc/ssh"
		sudo sh -c "cat $PUBLIC_KEY >> ${TEMPDIR}/${IMAGE_MOUNT_POINT}/etc/ssh/authorized_keys"
	fi
}

function umount_image(){
	echo Disconnecting the ${TEMPDIR}/${IMAGE_MOUNT_POINT} mount
	if [ ! -z ${IMAGE_MOUNT_POINT} ] && [ ! -z ${TEMPDIR} ] && [ -d ${TEMPDIR}/${IMAGE_MOUNT_POINT} ];then
		sudo umount ${TEMPDIR}/${IMAGE_MOUNT_POINT}
		echo Packing back the image file to ${IMAGE_MOUNT_POINT}.ext4fs.xz
		xz ${IMAGE_MOUNT_POINT}.ext4fs
		echo Removing temporary directory ${TEMPDIR}/${IMAGE_MOUNT_POINT}
		sudo rm "${TEMPDIR}/${IMAGE_MOUNT_POINT}" -rf
	else
		echo It is not safe to umount and remove ${TEMPDIR}/${IMAGE_MOUNT_POINT}
	fi
}

while getopts "fhylu:p:r:i:" opt; do
	case $opt in
		u)
			LDAP_ID=$OPTARG
			;;
		p)
			PASSWORD=$OPTARG
			;;
		r)
			if [[ $OPTARG =~ [0-9]\.[0-9]* ]]; then
				VERSION=$OPTARG
			fi
			;;

		f)
			FIX_IMAGES=true
			;;
		l)
			DOWNLOAD_LATEST_IMAGE=true
			;;
		i)
			if [ ! -f ${OPTARG} ]; then
				echo The ${OPTARG} does not exist
				PUBLIC_KEY=""
			else
				PUBLIC_KEY=$OPTARG
			fi
			;;
		y)
			YES_TO_ALL=true
			;;
		h)
			echo "A simple tool to make the image flashing automatic and easy. It can download the"
			echo "latest or any selected IVI and Auto images, fix the wifi and ssh authentication"
			echo "and flash the customized images on the partitioned block device."
			echo ""
			echo -e "\e[31mWARNING: This tool will use sudo commands and so operates with block"
			echo -e "devices. Please be careful and read all the outputs before proceeding. "
			echo -e "Also please note that the curl and wget commands will expose the LDAP"
			echo -e "credentials. You can use .wgetrc or .netrc if you want to improve the security\e[0m."
			echo ""
			echo "Usage: fix_custom_images.sh -u [LDAP_ID]| -f | -l | -i | -h "
			echo -e "\t-u : LDAP credential to access the ${IMAGE_SERVER}"
			echo -e "\t-f : Fix the stock images to enable wifi and ssh key authentication. Default: ${FIX_IMAGES}"
			echo -e "\t-l : Download the latest images. Default: ${DOWNLOAD_LATEST_IMAGE}"
			echo -e "\t-i : Selects a file from which the identity \(public key\) for public key authentication is added to the image"
			echo -e "\t-y : Answers yes to all questions. Use it with care. Default: ${YES_TO_ALL}"
			echo -e "\t-p : LDAP password to access the ${IMAGE_SERVER} (Note: the password will be visible in the console and in the process list)"
			echo -e "\t-r : Release number. The default is ${VERSION}.
			echo -e "\t-h : Prints this instruction."
			echo ""
			echo -e "By default fix_custom_images.sh downloads the latest available images and flashes"
			echo -e "them to a correctly partitioned block device"
			echo ""
			echo "Download the latest images, enable wifi and ssh authentication"
			echo -e "\t$ fix_custom_images.sh -l -f "
			echo ""
			echo "Download a selected images, enable wifi and give a specific RSA public key to inject to the image"
			echo -e "\t$ fix_custom_images.sh -f -i \$HOME/.ssh/id_rsa.pub"
			echo ""
			echo "Download the images from the ${IMAGE_SERVER} using the given LDAP credentials"
			echo -e "\t$ fix_custom_images.sh -u [USER_NAME] -p [PASSWORD]"
			echo ""
			exit
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit
	esac
done
authentication
download_image autoos
if [ $FIX_IMAGES ]; then
	mount_image
	fix_wifi
	transfer_connman_settings
	transfer_ssh_key
	umount_image
fi
download_image ivios
if [ $FIX_IMAGES ]; then
	mount_image
	transfer_ssh_key
	umount_image
fi
if confirm "Do you want to flash a block device with the images? [y/N]"; then
	wait_for_correct_block_device
	IFS=$'\r\n' GLOBIGNORE='*' command eval 'PARTITIONS=($(lsblk -p -o KNAME,TYPE,MODEL /dev/sdb|grep part))'
	PARTITION_TWO=${PARTITIONS[1]/part/}
	PARTITION_FOUR=${PARTITIONS[3]/part/}
	if confirm "Do you want to flash the $PARTITION_TWO and $PARTITION_FOUR partitions? [y/N]" && \
		[ $(stat --format '%04D' /) != $(stat --format '%02t%02T' $PARTITION_TWO) ] && \
		[ $(stat --format '%04D' /) != $(stat --format '%02t%02T' $PARTITION_FOUR) ]; then
			# Flash Auto OS image:
			sudo umount -l $PARTITION_TWO
			xz -dc "$AUTOOS_IMAGE_FILE" | sudo dd of=$PARTITION_TWO obs=1M
			[ $? -eq 0 ] && sudo e2fsck -f $PARTITION_TWO
			[ $? -eq 0 ] && sudo resize2fs $PARTITION_TWO
			# Flash IVI OS image:
			sudo umount -l $PARTITION_FOUR
			xz -dc "$IVIOS_IMAGE_FILE" | sudo dd of=$PARTITION_FOUR obs=1M
			[ $? -eq 0 ] && sudo e2fsck -f $PARTITION_FOUR
			[ $? -eq 0 ] && sudo resize2fs $PARTITION_FOUR
	fi
fi

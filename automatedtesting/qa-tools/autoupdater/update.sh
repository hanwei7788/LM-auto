#!/bin/bash

# Const flag for do_mount()
RDONLY=1

# Take these as parameters
dav_username=$1
dav_password=$2

my_dir=$(dirname $0)
source $my_dir/conf.sh

# Arguments: error message
error () {
	echo Error: $1 > /dev/stderr
}

# Expects that finding any of $fails from returned auth page means failed login
# It's a bad hack, but what else can you do..
# Arguments: auth username, auth password, auth url
do_auth () {
	fails="401
	fail
	wrong
	bad"

	[ "$(curl -s -u $1:$2 $3 |fgrep "${fails}")" ] && {
		error "Auth failed"
		return 1
	}
	return 0
}

# Arguments: device, mount path, optional RDONLY flag
do_mount () {
	mkdir -p $2

	# Is device already mounted?
	[ "$(mount | grep $1)" ] && {
		error "Device already mounted!"
		return 1
	}

	# Is directory already in use?
	[ "$(mount | grep $2)" ] && {
		error "Directory already in use!"
		return 1
	}

	# Is mount path empty?
	[ "$(ls -A $2)" ] && {
		error "Mount path not empty!"
		return 1
	}
	
	if [[ -n $3 && $3 -eq $RDONLY ]] ; then
		mount -o ro $1 $2
	else
		mount $1 $2
	fi
	return $?
}

# Arguments: partition
get_issue_name () {
	do_mount $1 $mountpoint $RDONLY
	if [ $? -ne 0 ] ; then
		return 1
	fi
	cat $mountpoint/$issue_path
	umount $1
}

# Echoes latest image URL if local image is old, nothing otherwise
# Arguments: local issue name, latest issue url, username, password
is_img_old () {

	# Grepping from curl output will give us the url of the image
	# (ie. https://my.repository.com/ivi_1.2.0.ext4fs.xz), first we need to
	# strip everything except file name from the url and then the .ext4fs.xz
	# extension
	latest_image_url=$(curl -s -u $3:$4 $2 | grep -E 'ext4fs.xz$')
	latest_image=$(echo ${latest_image_url##*/} |sed -e 's/.ext4fs.xz//g')

	# String comparison should be sufficient here
	if [[ $1 != $latest_image ]] ; then
		echo $latest_image_url
	fi
}

# Will not check for missing image URL, caller is responsible for checking
# Arguments: pattern to match old image file, image URL, image file name
download_img () {
	tmp_hash=tmp_hashfile.sha1sum

	echo Downloading $2...
	rm -f $1 $1.sha1sum
	curl -u $dav_username:$dav_password -O $2
	curl -u $dav_username:$dav_password -O $2.sha1sum

	# Get rid of /home/builder/lm/build and /home/builder/lm/tmpbuild
	# paths from the hash files
	sed 's:\(/home/builder/lm/\)\(.*\)\(/\)::' $3.sha1sum > $tmp_hash
	sha1sum -c $tmp_hash
	if [ $? -ne 0 ] ; then
		error "SHA1 checksum for $3 does not match"
		rm $tmp_hash
		exit 1
	fi
	rm $tmp_hash
}

# If there is no image URL argument, assume that we're up to date
# Arguments: Download directory, pattern to match old image file, image URL,
# target partition
download_and_install () {
	if [ -z $3 ] ; then
		echo Up to date!
		return 0
	fi

	# Extract image name from URL
	image_name=$(echo ${3##*/})

	old_dir=$PWD
	cd $1
	download_img $2 $3 $image_name
	yes | bash $write_rootfs -r $image_name -p $4
	cd $old_dir
}

do_auth $dav_username $dav_password $auth_url
if (($? != 0)) ; then
	exit 1
else
	echo Successfully authenticated
fi

umount $mountpoint

autoos_issue=$(get_issue_name $autoos_partition)
ivios_issue=$(get_issue_name $ivios_partition)

autoimg=$(is_img_old $autoos_issue $latest_auto_url $dav_username $dav_password)
iviimg=$(is_img_old $ivios_issue $latest_ivi_url $dav_username $dav_password)

# If IVI is due to be updated, we need to stop the container first
if [ -n $iviimg ] ; then
	systemctl stop user@20000
fi

download_and_install ./ $autoos_img_pattern "$autoimg" $autoos_partition
download_and_install ./ $ivios_img_pattern "$iviimg" $ivios_partition

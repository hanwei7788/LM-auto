#!/bin/bash
#########################################################
#
# A helper to remove all docker containers and images
#
# Authors: Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#
# License: Proprietary
# (C) 2016 Link Motion Oy
# All Rights reserved
#########################################################

echo
echo "This script will REMOVE ALL docker containers and images."
echo
echo -n "Are you sure? (y/N)?"
read ANSWER
if [[ ${ANSWER} != 'y' ]]; then
  echo "cancelled.."
  exit 2
fi

# remove all containers
docker ps -aq|xargs -I{} docker rm -f {}

# remove all images
docker images -q|xargs -I{} docker rmi -f {}

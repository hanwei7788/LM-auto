#!/bin/bash

#Scripts for setting up build env

#README first.

usage(){

    echo "This scripts will set up enviorment for Build/Deploy SilverStone project. "
    echo 'All scripts are followed with steps on https://confluence.link-motion.com/pages/viewpage.action?pageId=6032297'
    echo "It will try to install curl, repo, docker on your machine with current account."
    echo "It will try to run repo init with your local account"

}

if [ "$1" = "-h" ];then
  usage
  exit
   
fi

sudo service ssh start
echo "**********************" 
echo "**********************" 
echo "Update/Install curl if necessary."
sudo apt-get -f install curl

if [ $? -ne 0 ];then
  echo "Mannually install curl please."
  exit
fi

if [ ! -d ~/bin  ];then
   mkdir ~/bin
fi

if [ ! -f ~/bin/repo ];then
  echo "**********************" 
  echo "**********************" 
  echo "repo is not installed.Start installation now... "
   
  PATH=~/bin:$PATH
  curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
  chmod a+x ~/bin/repo
else
  echo "repo has been installed on ~/bin yet."

fi

sleep 3

docker

if [ $? -ne 0 ];then
   echo "**********************" 
   echo "**********************" 
   echo "docker is not installed.Start installation now..."

   sudo apt-get update
   echo "Y"|sudo apt-get -f install docker.io

   if [ $? -nq 0 ];then
      echo "Mannually install docker please."
      exit

   fi
   sudo gpasswd -a ${USER} docker
   sudo service docker restart
   newgrp docker
fi

sleep 3

echo "Download yocto meta layers."
echo "A lot of time need to spend here.Or you may choose to copy them from other local machines manually."
read -t 20 -p "Enter your option: 0 for continue repo init; 1 for ignore; any other keys for quit." flag
case $flag in
  0)
  {
   if [ -d ~/workspace ];then
     rm -r ~/workspace
     mkdir ~/workspace
   fi
    repo init -u ssh://git@bitbucket.link-motion.com:7999/silverd/lm-manifests -b master -m silverdust.xml

  };;
  1)
  {
    echo "You canceled repo init. Please do it manually."
  };;
  *)
    echo "Quit now......"
    exit
  ;;
esac









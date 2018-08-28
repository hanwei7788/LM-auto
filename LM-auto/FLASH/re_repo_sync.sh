#! /bin/bash

usage(){

    echo "start repo sync, once sync failed, repeat sync automatically after 3 seconds.just wait it finished......."
    echo "need to enter ~/workspace first."
}


if [ "$1" = "-h"  ];then
    usage
    exit
fi


dir=~/workspace

cd $dir

if [ ! -s $dir/build/imx6* ];then

  echo "copy image into $dir/build folder first."
  exit

fi

if [ -d $dir/build/lm-update ];then

  rm -rf $dir/build/lm-update

fi

unzip -d $dir/build $dir/build/imx6*.zip
if [ $? -ne 0 ];then
  echo "unzip failed. Manually do it please."
  exit

fi


xz -d $dir/build/lm-update/*.xz

if [ $? -ne 0 ];then
  echo "xz lm-update failed. run 'xz -d .../lm-update/*.xz' manually. "
  exit

fi



echo "Start repo sync ............"
repo sync

while [ $? -ne 0 ];do

echo "repo sync failed. Re-sync after 3 seconds....."

sleep 3

repo sync
done

echo "repo sync succeed."
echo "build docker env now....."
echo "It takes at least 5 miniutes to build images here.Just keep waiting...."
#copy scripts into container's path.
cp -p $dir/docker_op.sh $dir/docker/home/builder/

./setup

# get container's id
#docker_id=`docker ps|tail -n 1 |awk '{print $1}'`
# docker_ip=`docker inspect $docker_id|grep '"IPAddress":'|head -n 1|awk -F":|," '{print $2}'`
#newdocker_ip=`echo $docker_ip|sed 's/"//g'`
#get the switched tty.
#terminal=`ps -ax|grep bitbucket|grep start.sh|awk '{print $2}'`
#terminal=`ps -ef|grep start.sh|head -n 1|awk '{print $6}'`

#sudo docker exec -it $docker_id /bin/bash
#su - builder
#bitbake virtual/mfgtool-kernel virtual/mfgtool-bootloader argo-mfgtool-initramfs

#start ssh service on container
#docker exec -i heuristic_wright  sudo /etc/init.d/ssh restart

    





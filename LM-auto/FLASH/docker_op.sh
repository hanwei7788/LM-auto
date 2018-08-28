#! /bin/bash
#need to be executed in container

cd ~

read -t 20 -p "If you are first time using the image,enter 0 to bitbake mfgtool first." flag

if [ $flag -eq 1 ];then

  bitbake virtual/mfgtool-kernel &&bitbake virtual/mfgtool-bootloader&&bitbake argo-mfgtool-initramfs && echo "bitbake finished."

fi 


echo "please plugin your device and set it OTG-Launched enabled!"

s_n=`head -50 /dev/urandom|cksum|cut -d " " -f1|cut -c 1-4`

s_n=0105A10218300${s_n}
echo "serial number will be set as :$s_n"

read -t 20 -p "press 0 to start flash images.any other keys mean quit"  flag

if  [ $flag -ne 0 ];then
  echo "You "


fi




update-silverstone-device.sh -s -p --serial-number=$s_n

echo "flash finished. Need to reboot device manually." 


 


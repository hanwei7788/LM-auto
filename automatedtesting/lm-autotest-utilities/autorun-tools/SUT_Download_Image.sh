#!/bin/bash
# SUT Download Image v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

printf "$3\n"

# Stop UI - Modified 20160729
# printf "Auto: Stop UI\n"
# RESULTS1=$(sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'systemctl stop user@20000')
# echo $RESULTS1 >> ~/automatedtesting/autorun-tools/logs/SUT_log.txt
# printf "Auto: Stop UI done\n"

printf "Auto: Stop UI\n"
if timeout 30 sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'systemctl stop user@20000'
then
  echo "UI stop exit OK"
else
  echo "UI stop exit by timer"
fi
printf "Auto: Stop UI done\n"

# Download image
printf "Auto: Start downloading $3\n"
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" "curl -k -u linkmotion@nomovok.com:5pHgunweds -O $3"
if [ ! $? -eq 0 ]
then
  printf "Download image error\n"
  rm *.ext4fs.xz
  rm *.sha1sum
  exit 1
else
  printf "Download image OK\n"
fi

# Download hash file
hash_download="${3}.sha1sum"
printf "Auto: Start downloading hash $hash_download\n"
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" "curl -k -u linkmotion@nomovok.com:5pHgunweds -O ${hash_download}"
if [ ! $? -eq 0 ]
then
  printf "Download hash error\n"
  rm *.ext4fs.xz
  rm *.sha1sum
  exit 1
else
  printf "Download hash OK\n"
fi

# Edit hash file
hash_filename="${4}.sha1sum"
printf "Auto: Edit hash $hash_filename\n"
#Edited 24.8.2016 P.Salo to accept both /home/builder/lm/build/ and /home/builder/lm/tmpbuild/ directories.
#sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" "sed 's:/home/builder/lm/tmpbuild/::' ${hash_filename} > hash.sha1sum"
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" "sed 's:\(/home/builder/lm/\)\(.*\)\(/\)::' ${hash_filename} > hash.sha1sum"
if [ ! $? -eq 0 ]
then
  printf "Hash edit error\n"
  rm *.ext4fs.xz
  rm *.sha1sum
  exit 1
else
  printf "Hash edit OK\n"
fi

# Verify image
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" "sha1sum -c --status hash.sha1sum"
if [ ! $? -eq 0 ]
then
  printf "Hash error\n"
  rm "*.ext4fs.xz"
  rm "*.sha1sum"
  exit 1
else
  printf "Hash OK\n"
fi


printf "Auto: Downloading done\n"

exit 0

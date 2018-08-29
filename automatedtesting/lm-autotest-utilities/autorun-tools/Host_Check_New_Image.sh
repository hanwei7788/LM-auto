#!/bin/bash
# Check for the latest file in DAV v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"
cd "${autotest_root}/c4c-functional-tests/TestReports_$1"

curl -k -u linkmotion@nomovok.com:5pHgunweds -o imagefolder.html "${imagepath}?C=M;O=D"

grep '.ext4fs.xz</a>' imagefolder.html | 
grep -oP 'href=".*?"' | 
cut -d "\"" -f2 | 
cut -d "-" -f5-6 | 
cut -d "." -f1 | 
sort -r > timestamps_sorted.txt

rm imagefolder.html

latest_image=$(head -1 timestamps_sorted.txt)

if [[ -z $last_tested_image ]]
then
  printf "No last tested image in config-file\n"
else
  if [[ "${latest_image}" > "${last_tested_image}" ]]
  then
    printf "Newer image available\n"
  else
    printf "No newer image available\n"
    exit 1
  fi
fi 

# write image info to ${autotest_root}/c4c-functional-tests/TestReports_$1/ImageToFlash.txt

echo $latest_image > "${autotest_root}/c4c-functional-tests/TestReports_$1/ImageToFlash_Timestamp.txt"
echo $imagepath$imageprefix$latest_image$imagepostfix > "${autotest_root}/c4c-functional-tests/TestReports_$1/ImageToFlash.txt"
exit 0


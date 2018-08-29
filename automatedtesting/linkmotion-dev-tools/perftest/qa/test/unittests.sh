#! /bin/bash

set -e
set -u
#set -x
#set -v

unittest=Y
. ../sufu.sh

testsuccess=true

x=$(us2ms 5555)
if [[ x -eq 6 ]]
then
  echo PASS $LINENO
else
  echo FAIL $LINENO
  testsuccess=false
fi

x=$(us2ms 5455)
if [[ x -eq 5 ]]
then
  echo PASS $LINENO
else
  echo FAIL $LINENO
  testsuccess=false
fi

x=$(us2ms 123555)
if [[ x -eq 124 ]]
then
  echo PASS $LINENO
else
  echo FAIL $LINENO
  testsuccess=false
fi

x=$(us2ms 123455)
if [[ x -eq 123 ]]
then
  echo PASS $LINENO
else
  echo FAIL $LINENO
  testsuccess=false
fi

# # cat /proc/epit ;sleep 1; cat /proc/epit
# 4167720147
# 4166702199
x=$(epit2ms 4167720147)
#echo $x
y=$(epit2ms 4166702199)
#echo $y
delta=$((y-x))
# echo delta $delta
# we just hope that the value once calculated is actually correct (at least it
# was plausible), so this is mainly a regression test to alarm us
# should it change...
if [[ $delta -eq 1018 ]]
then
  echo PASS $LINENO
else
  echo FAIL $LINENO
  testsuccess=false
fi


if $testsuccess
then
  echo All unit tests passed
else
  echo Some unit test failed
fi

clear_errorhandler

#!/bin/bash
# SUT Poweroff v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

printf "Auto: Power off SUT\n"
if timeout 30 sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" "{ sleep 1; systemctl poweroff; } >/dev/null &"
then
  echo "SUT power off exit OK"
else
  echo "SUT power off exit by timer"
fi
printf "Auto: Power off SUT done\n"
exit 0



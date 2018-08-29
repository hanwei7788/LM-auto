#!/bin/bash
# SUT Collect Device Data v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

printf "Auto: Start collecting data\n"

printf "Auto: df: \n"
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'df'

printf "Auto: cat /proc/meminfo: \n"
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'cat /proc/meminfo'

printf "Auto: cat /etc/issue: \n"
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no "root@${sut_ip}" 'cat /etc/issue'

printf "Auto: Data collection done\n"

exit 0

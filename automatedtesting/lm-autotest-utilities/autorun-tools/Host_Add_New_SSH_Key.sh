#!/bin/bash
# Scan for and insert new SUT SSH key v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

ssh-keyscan -H "${sut_ip}" >> /home/autotest/.ssh/known_hosts
exit 0

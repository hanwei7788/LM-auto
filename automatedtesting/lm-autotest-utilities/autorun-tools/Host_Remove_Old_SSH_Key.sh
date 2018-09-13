#!/bin/bash
# Host remove old SUT SSH key, scan for and insert new key v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

ssh-keygen -f "/home/autotest/.ssh/known_hosts" -R "${sut_ip}"

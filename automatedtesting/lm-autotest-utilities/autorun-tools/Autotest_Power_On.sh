#!/bin/bash
# Power on autotest devices v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

tdtool --on "${sut_power}"
tdtool --on "${sut_power}"
tdtool --on "${sut_power}"
exit 0

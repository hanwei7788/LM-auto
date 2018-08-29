#!/bin/bash
# Power off autotest devices v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

tdtool --off "${sut_power}"
tdtool --off "${sut_power}"
tdtool --off "${sut_power}"

exit 0

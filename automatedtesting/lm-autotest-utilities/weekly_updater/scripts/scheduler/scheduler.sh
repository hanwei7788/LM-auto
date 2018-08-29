#!/bin/bash

##This scheduler parses the single test case (idle, medium, stress, ...) schedule into timeframes 
##When the test setup is able to upload tests and interrupt test runs
##Takes parameters 	1. start time of the tests
#			2. testcase

start_time=$1
test=$2

current_time=$(date +"%s")

duration=$((current_time-start_time))
filename=~/automatedtesting/argo_functional_tests/weekly_test_cases/$test/schedule.txt

while read -r line
do
	time1=$(echo $line | cut -f1 -d:)
	time2=$(echo $line | cut -f2 -d:)
	result=$(echo $line | cut -f3 -d:)

	if [[ ( $duration -gt $time1 && $duration -le $time2 ) ]];
	then
		echo $result
		exit 0
	fi

done < "$filename"

if [[ $duration -gt $time2 ]];
then
	echo $result
	exit 0
fi

echo -1
exit 1

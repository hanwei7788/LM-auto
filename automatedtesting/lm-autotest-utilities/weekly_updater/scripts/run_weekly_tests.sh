#!/bin/bash
# Launch master script with correct parameters v1
#1.parameter=device name
#2.parameter=device IP
#3.parameter=name of the test case

_term(){
        echo Received SIGTERM: Killing child process and exiting >> $cron_log
        kill $child_plot
        wait $child_plot
        status=1
}

_sigusr(){
	echo "Received SIGUSR1: Checking the center status" >> $cron_log
        curr_pwd=$(pwd)
        #This change directory is because of rake needing the right pwd to work properly
        cd $autotestroot/argo_functional_tests
        bash $autotestroot/argo_functional_tests/weekly_test_cases/check_center_response.sh $device_name $now >> $cron_log

        kill $child_plot
        wait $child_plot
	_jira_upload
        status=1
        #After all done return to same pwd as in the beginning of this function
        cd $curr_pwd
}

_jira_upload(){
	echo "Uploading to JIRA" >> $cron_log
	$plotfaster_path/exporter/exporter.py -g $autotestroot/argo_functional_tests/TestReports_$device_name/$now/ $autotestroot/argo_functional_tests/TestReports_$device_name/$now/report.jsonl.zlib >> "$plot_log" 2>&1
	$autotestservicepath/jira_uploader/upload.py -n $device_name -t $now >> "$jira_log" 2>&1
}

_usage(){
	echo
	echo "Usage:"
	echo 'Give exactly 3 arguments (1. sut_name, 2. sut_ip, 3. test_name)'
	echo "Call example:"
	echo     "./run_weekly_tests.sh ATP123 192.168.125.111 idle"
	echo
	exit 1
}

if [[ $1 == "-h" ]] || [[ $1 == "" ]] || [[ $1 == "--help" ]];
then
        _usage
fi

if [ "$#" -ne 3 ];
then
	echo
	echo " **ERROR** Passed illegal number of arguments."
	echo $@
	echo
	echo "**Give 3 arguments"
	echo "**example: ./run_weekly_tests.sh ATP123 192.168.125.111 idle"
	echo
	exit 1
fi

my_dir=$(dirname $0)

autotestroot=~/automatedtesting
source $autotestroot/argo_functional_tests/TestReports_$1/image.conf

device_name=$1
device_ip=$2
test=$3

now=$(date +"%Y%m%d%H%M%S")
start_time=$(date +"%s")
status=0

mkdir -p "$autotestroot/argo_functional_tests/TestReports_$device_name/$now"
cron_log="$autotestroot/argo_functional_tests/TestReports_$device_name/$now/$device_name-$now-cron.log"
uploader_log="$autotestroot/argo_functional_tests/TestReports_$device_name/$now/$device_name-$now-uploader.log"
jira_log="$autotestroot/argo_functional_tests/TestReports_$device_name/$now/$device_name-$now-jira_log.log"
plot_log="$autotestroot/argo_functional_tests/TestReports_$device_name/$now/$device_name-$now-plot_log.log"

echo "Launch config $device_name, test run ID $now" >> $cron_log 2>&1;

echo Test $device_name >> $cron_log 2>&1;
echo Test $device_ip >> $cron_log 2>&1;
echo Test $test >> $cron_log 2>&1;

autotestservicepath="$autotestroot/lm-autotest-utilities"
plotfaster_path="$autotestroot/qa-tools/plotfaster"
ssh-keygen -R $device_ip

#Run the networking script
sshpass -p 'skytree' ssh -o StrictHostKeyChecking=no root@$device_ip 'concon.sh'

##Run plotfaster in the background
$plotfaster_path/execute_test.py -T $device_ip -i 60 -P $autotestroot/argo_functional_tests/TestReports_$1/$now/ & >> $plot_log
child_plot=$!
echo Plotfaster PID: $child_plot >> $cron_log 2>&1;
if [[ -z $child_plot ]];
then
	echo Plotfaster not running >> $cron_log 2>&1;
fi

echo "Start time: $now" >> $cron_log 2>&1;

#This loop is the key to keep the tests running until 5-7 days are done.
#Once the time is up and the last test run is finished, we exit this loop,
#plotfasters reporter is killed (identified with IP, so other plotfasters
#won't be touched), plotfasters results relocated and SUT shut down.
while :
do
        ##Trapping incoming term signals
	trap _term SIGTERM
	trap _sigusr SIGUSR1

	newnow=$(date +%s)
	echo "$newnow > SUT alive and running." >> $cron_log 2>&1;

	if [[ $status -ne 0 ]];
	then
		break
	fi
        #In the beginning of each loop, check if SUT is still alive with ping and ssh connection
	if ! ping -c 5 $device_ip 2>&1 > /dev/null ; then
                echo "$newnow: Unable to ping SUT" >> "$cron_log" 2>&1;
                status=1
                break
        fi

        ##Checks that the plotfaster is alive. If it has died during the test run, the tests will keep on
        ##running and the plotfaster has to be manually rerun
        if [[ -z /proc/$child_plot ]];
        then
                timestamp=$(date +"%y%m%d_%H%M%S")
                echo '$timestamp> Plotfaster is dead ($device_name $device_ip). Reset it manually' >> $cron_log 2>&1;
        fi

        #Start tests
        #Testcase (idle/medium/stress) is selected here. Currently running testset used in nightly autotests
	#Test run has timeout of one hour. Timeout will be noted, but treated as OK
        timeout 3600 bash $autotestroot/argo_functional_tests/weekly_test_cases/$test/run_test.sh $device_name $start_time $now $device_ip
	result=$?
	if [[ $result == 1 ]];
	then
		echo Test requesting Jira upload
		_jira_upload

	elif [[ $result != 0 ]] && [[ $result != 124 ]];
	then
		status=1
		echo "Test run aborted" >> "$cron_log" 2>&1;
		if [[ ! -f "$autotestroot/argo_functional_tests/TestReports_$device_name/$now/issue_key.json" ]];
		then
			$autotestservicepath/jira_uploader/upload.py -n $device_name -t $now >> "$jira_log"
		else
			$autotestservicepath/jira_uploader/modify_issue.py $device_name $now >> "$jira_log"
                fi
		break
	elif [[ $result == 124 ]];
	then
		echo run_test timed out >> "$cron_log" 2>&1;
		echo ignoring this and continuing >> "$cron_log" 2>&1;
	fi

        $plotfaster_path/exporter/exporter.py -g $autotestroot/argo_functional_tests/TestReports_$device_name/$now/ $autotestroot/argo_functional_tests/TestReports_$device_name/$now/report.jsonl.zlib >> "$plot_log" 2>&1
done

echo "Test finished!" >> $cron_log 2>&1;

##Last, check the test status and add this information to test log file
if [[ $status == 1 ]];
then
	echo "Tests Aborted!" >> $cron_log 2>&1;
elif [[ $status == 0 ]];
then
        echo "Tests Success" >> $cron_log 2>&1;
else
        echo "Tests Failed" >> $cron_log 2>&1;
fi

##Terminate the plotfaster run
if [[ $child_plot -gt 0 ]];
then
        echo "Terminating plotfaster"
	kill $child_plot
fi
exit 0

#!/system/bin/sh

comment(){
if [ ! -f $testresult/comments.csv ];then
    echo "Date,Error Type,Log Name" >$testresult/comments.csv
fi
echo "`date +%m-%d" "%H":"%M":"%S`,$1,$2" >>$testresult/comments.csv
}
#分析$1日志文件，若有异常，输出log.输出规则如下：输出log内容并截图到$testresult/log文件夹；其中若有ANR/build文件，若有异常，输出log并截图到$testresult/log文件夹；其中若有ANR/build fingerprint,则将anr /Build fingerprint log移动到$testresult/log/timeStamps目录下,
output_error(){
if [ -f $1 ];then
    local times1=`grep -c "ANR in" $1`
	anr=$((anr+times1))
	local times2=`grep -c "FATAL EXCEPTION" $1`
	fatal=$((fatal+times2))
	local times3=`grep -c "Build fingerprint" $1`
	fingerprint=$((fingerprint+times3))
	if [ $times1 -ne 0 -o $times2 -ne 0 -o $times3 -ne 0 ];then
	    if [ ! -d $testresult/log ];then
		    mkdir $testresult/log
		fi
		time_name="`date +%Y%m%d%H%M%S`"
	    busybox mv $1 $testresult/log/$time_name.log
		bugreport >$testresult/log/$time_name.bugreport
		screencap $testresult/log/$time_name.png
		local result="Error:"
		if [ $times1 -ne 0 -a ! -z "`ls /data/anr 2>/dev/null`" ];then
			mkdir $testresult/log/$time_name
			mv /data/anr/* $testresult/log/$time_name/
			local result=$result"ANR;"
		fi
		if [ $times2 -ne 0 ];then
			local result=$result"FATAL;"
		fi
		if [ $times3 -ne 0 -a ! -z "`ls /data/tombstones 2>/dev/null`" ];then
			if [ ! -d $testresult/log/$time_name ];then
				mkdir $testresult/log/$time_name
			fi
			mv /data/tombstones/* $testresult/log/$time_name
			local result=$result"tombstones;"
		fi
		comment "$result" "$time_name.log"
	else
		rm $1
	fi
fi
}
##如果$1为0，则创建log:将已经存在的log_f移动到$testresult/check_error中；生成新的log_f;根据$testresult/check_error生成错误报告并删除该文件。 如果$1不为零，且/sdcard/check_error.log已经存在，则移动日志到$testresult/check_error.log中，并用output_error分析
c_log(){
if [ -f $log_f ];then
	while true;do
		if [ -f $testresult/check_error.log ];then
			sleep 1
		else
			break
		fi
	done
	local p=`busybox ps`
	kill -9 `echo "$p"|grep "logcat -f $log_f -b all -v time &"|busybox awk '{print $1}'`
	busybox mv $log_f $testresult/check_error.log
fi
if [ $1 -eq 0 ];then
	logcat -b all -c
	logcat -f $log_f -b all -v time &
fi
if [ -f $testresult/check_error.log ];then
	output_error $testresult/check_error.log
	echo -e "local mac=$mac
build id=$build
ANR=$anr
Fatal=$fatal
tombstone=$fingerprint" >$testresult/statistics.txt
fi
}


#Global variables
anr=0
fatal=0
fingerprint=0
log_f="/sdcard/check_error.log"
if [ -f $log_f ];then
	rm $log_f
fi
testresult="/sdcard/monkey"
if [ -d $testresult ];then
    rm -r $testresult
fi
mkdir $testresult
mac=`cat /sys/class/net/*/address|busybox sed -n '1p'|busybox tr -d ':'`
build=`getprop ro.build.fingerprint`
if [ -z $build ];then
    build=`getprop ro.build.description`
fi

setprop persist.sys.lelogd 1
setprop persist.sys.qlogd 1

#等待monkey进程执行完毕函数 进程监控monkey,monkey启动后，建日志，monkey退出后，输出log。
waitmonkey(){
local a=0
while [ $a != 1 ];do
    local a=`/system/bin/ps |grep -c "com.android.commands.monkey"`
done
while [ $a != 0 ];do
	c_log 0
    sleep 10
	local a=`/system/bin/ps |grep -c "com.android.commands.monkey"`
done
c_log 1
}
#等待  时间为毫秒。10毫秒后生成日志，到达等待时间，输出log,
wait_time(){
local chek_begin=`busybox awk -F. 'NR==1{print $1}' /proc/uptime`
local check=$chek_begin
c_log 0
while true;do
	local chek_end=`busybox awk -F. 'NR==1{print $1}' /proc/uptime`
	if [ $((chek_end-chek_begin)) -ge $1 ];then
		c_log 1
		break
	elif [ $((chek_end-check)) -gt 10 ];then
		local check=$chek_end
		c_log 0
	else
		sleep 1
	fi
done
}

busybox pkill monkey
#以下为monkey脚本逻辑

#文件管理器 1小时（+5分钟休息）
comment "com.letv.filemanager" "start test"
monkey -p com.letv.filemanager --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.letv.filemanager" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#音乐 1小时（+5分钟休息）
comment "com.letv.music" "start test"
monkey -p com.letv.music --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.letv.music" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#帮助反馈 1小时（+5分钟休息）
comment "eui.auto.letvfeedback" "start test"
monkey -p eui.auto.letvfeedback --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "eui.auto.letvfeedback" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#日历 1小时（+5分钟休息）
comment "com.letv.calendar" "start test"
monkey -p com.letv.calendar --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.letv.calendar" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#设置 1小时（+5分钟休息）
comment "com.letv.settings" "start test"
monkey -p com.letv.settings --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.letv.settings" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#违章助手 1小时（+5分钟休息）
comment "com.letv.violation" "start test"
monkey -p com.letv.violation --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.letv.violation" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#语音 1小时（+5分钟休息）
comment "com.letv.voice" "start test"
monkey -p com.letv.voice --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.letv.voice" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#天气 1小时（+5分钟休息）
comment "com.letv.weather" "start test"
monkey -p com.letv.weather --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.letv.weather" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#视频 1小时（+5分钟休息）
comment "com.letv.videoplayer" "start test"
monkey -p com.letv.videoplayer --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.letv.videoplayer" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#拨号 1小时（+5分钟休息）
comment "com.android.dialer" "start test"
monkey -p com.android.dialer --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 7200 >>$testresult/monkey.log &
waitmonkey
comment "com.android.dialer" "finish test"
wait_time 300
comment "wait_time" "finish wait 300s"

#所有App 3小时（+5分钟休息）
comment "all package" "start test"
monkey -p eui.auto.letvlauncher -p com.letv.account.activity -p com.letv.filemanager -p com.letv.music -p com.sohu.inputmethod.sogou -p eui.auto.letvfeedback -p com.letv.calendar -p com.letv.settings -p com.letv.violation -p com.letv.voice -p com.letv.weather -p com.letv.videoplayer -p com.android.dialer --throttle 500 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 35 --pct-motion 25 --pct-trackball 20 --pct-flip 15 --pct-anyevent 5 -v -v -v 21600 >>$testresult/monkey.log &
waitmonkey
comment "all package" "finish test"
wait_time 300
comment "all package" "finish wait 300s"

#app间切换 1小时（+5分钟休息）
comment "appswitch 70%" "start test"
monkey -p eui.auto.letvlauncher -p com.letv.account.activity -p com.letv.filemanager -p com.letv.map -p com.letv.music -p com.sohu.inputmethod.sogou -p eui.auto.letvfeedback -p com.letv.calendar -p com.letv.settings -p com.letv.violation -p com.letv.voice -p com.letv.weather -p com.letv.systemupgrade -p com.letv.videoplayer -p com.android.dialer --throttle 1000 --ignore-crashes --monitor-native-crashes --ignore-timeouts --ignore-native-crashes --ignore-security-exceptions --pct-touch 10 --pct-motion 10 --pct-flip 5 --pct-appswitch 70 --pct-anyevent 5 -v -v -v 3600 >>$testresult/monkey.log &
waitmonkey
comment "appswitch 70%" "finish test"
comment "finish" "END"
#!/system/bin/sh
#休眠、唤醒设备500次，是否工作正常

comment(){
if [ ! -f $testresult/comments.csv ];then
    echo "wake up/sleep state switch testing....." >$testresult/comments.csv
fi
echo "`date +%m-%d" "%H":"%M":"%S`,$1,$2" >>$testresult/comments.csv
}


##############Global variables#################
screen="ON/OFF"  (ON:wakeup state; OFF:sleep state) 
times=0  操作次数
bb="/sdcard/busybox"
testresult="/sdcard/monkey"
if [ ! -d $testresult ];then
    mkdir $testresult
fi


#判断当前设备屏幕状态 重新给state赋值
screen=`dumpsys power|grep "Display Power" |$bb awk -F= '1{print $2}'`

#重复500次 唤醒、休眠操作
comment "Wake Up / Sleep Switch 500times" "Start test"


while [ times -le 500 ];do

	screen=`dumpsys power|grep -i "Display Power" |$bb awk -F= '1{print $2}'`
	
	if [ screen == "OFF" ];then
	
	  
	   ${wm_size_x=`wm size|$bb awk -F" |x" '{print $(NF-1)}'`} 2>/dev/null
	   ${wm_size_y=`wm size|$bb awk -F" |y" '{print $(NF-1)}'`} 2>/dev/null
	   
	   input keyevent 26&&$bb sleep 1&&input swipe $((wm_size_x/2)) 0 $((wm_size_x/2)) $((wm_size_y/2+20))
	   
	  # monkey --slipte (wm_size_x/2,0,wm_size_x/2,wm_size_y/2+20)
	
	fi
	
	times +=1
	
	sleep 
 
 done
 
comment "Wake Up / Sleep Switch 500times" "Finish test"

#lock or unlock screen.
#$1: 0--lock; 1--unlock
unlock(){
${wm_size_x=`wm size|$bb awk -F" |x" '{print $(NF-1)}'`} 2>/dev/null
${wm_size_y=`wm size|$bb awk -F" |x" '{print $NF}'`} 2>/dev/null
while true;do
	screen=`dumpsys power|grep -i "Display Power" |$bb awk -F= '1{print $2}'`
    if [ screen == "OFF" ];then
      
        input keyevent 26
		$bb sleep 1
	else
		break
	fi
  
done

input swipe $((wm_size_x/2)) $((4*wm_size_y/5)) $((wm_size_x/2)) $((wm_size_y/5))

}




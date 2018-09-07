#! /bin/bash
# Script to verify if the Android wifi-hotspot is able to
# be connected from this box.
#
# Written by Han Wei

# Pre-req here
# 1. need to set batman launcher as always launcher option
# 2. need to enable hotspot feature manually since it is disabled in built
# 3. need to install wpa_supplicant by "apt-get install wpasupplicant"
 


set -e
set -u

usage(){
   echo "Usage: ./hotspot.sh <SSID> <pkey>"
   echo "Example: ./hotspot.sh AndroidAP 88888888"
   exit 1   
}

if [[ "$#" -ne 2 ]];then

  usage
fi

if [[ "$1" == "-h" ]];then
  usage
fi



####global variables defined here##########

wl_interface=`iwconfig 2>&1| grep "ESSID"|awk '{print $1}'`
hotspot_ssid=$1
hotspot_pw=$2
this_dir=$(dirname $(realpath $0))
time=`date +"%Y%m%d%H%M"`
log="$this_dir/hotspot-$time.log"

exec 2>>$log



######function now#########

show_err(){
	  echo -e "\033[1;31m$@\033[0m" 1>&2
}

show_msg(){

	  echo -e "$@" 1>&2
}

log_err(){
	local date=`date +"%Y-%m-%d %H:%M:%S "`
	local para=$1
        echo "log error:$date $1" >> $log
      
}

log_warn(){
	local date=`date +"%Y-%m-%d %H:%M:%S "`
	local para=$1
        echo "log warn:$date $1" >> $log
        #echo -e "\033[1;31m$@\033[0m" 1>&2
}

log_info(){

        local date=`date +"%Y-%m-%d %H:%M:%S "`
        local para=$1
	echo "log info:$date $1" >>$log
  
}


wpa_config(){

   rm -f /etc/wpa_supplicant/wpa_supplicant.conf ||true

   cat <<EOF >/etc/wpa_supplicant/wpa_supplicant.conf

      ctrl_interface=/var/run/wpa_supplicant

      ap_scan=1

      network={
               ssid="AndroidAP"
               psk="88888888"
               priority=1

      }

EOF

  if [[ "$hotspot_ssid" != "AndroidAP" ]]; then 
      
      show_msg "Replace current SSID value in wpa_supplicant.conf."
      log_info "Replace current SSID value in wpa_supplicant.conf."
      sed -i "s/AndroidAP/$hotspot_ssid/" /etc/wpa_supplicant/wpa_supplicant.conf 
  fi

  if [[ "$hotspot_pw" != "88888888" ]]; then
	
     show_msg "Replace current pkey value in wpa_supplicant.conf."   
     log_info "Replace current pkey value in wpa_supplicant.conf."
     sed -i "s/88888888/$hotspot_pw/" /etc/wpa_supplicant/wpa_supplicant.conf 
  
  fi 
  show_msg "config succeed in function."
  log_info "config succeed in function." 

}



check_supported(){

    if [[ ! $(iw list 2>&1 |grep -A8 "Device supports" |grep "AP scan") ]];then
        
        show_err "You wireless card or driver doesn't support AP mode"

        exit 1
    fi

}

check_root(){

   if [[ ! $(whoami) = "root" ]]; then
        
        show_err "Please run this script as root."

        exit 1
   fi

}




hotspot_scanned(){

       
       count=`iw dev $wl_interface scan |grep  "SSID" |grep -c "$hotspot_ssid"`
       
       log_info "scanned count is: $count "
       
       sleep 5
       
       if [[ $count -ge 1 ]];then

            log_info "Hotspot can be scannned successfully."
            return 0
       else 

            log_err "HotSpot failed to be scanned. "
            return 1

       fi

}

hotspot_connect(){
  
  #wpa_pid=`ps aux|grep wpa_supplicant|head -n 1 |awk '{print $2}'`

  #kill -9 $wpa_pid  >/dev/null 2>&1  
  
  log_info " Kill prior wpa_supplicant process now."

  killall wpa_supplicant ||true

  wpa_supplicant -i $wl_interface -c /etc/wpa_supplicant/wpa_supplicant.conf 
  sleep 5s
  
  log_info "kill prior dhclient process."
  killall dhclient || true

  dhclient $wl_interface
  sleep 3s

   

}


# main script here


log_info "check_root begins"
check_root

log_info "check_root finished. Check supported begins"
check_supported 

log_info "check_support finished"

log_info "wpa config produced"
wpa_config  

log_info "wpa_config finished. and hotspsot scanned started."
hotspot_scanned

log_info "hotspot_scan finished and hotspot_connect start"
hotspot_connect

log_info "hotspot_connect finished."



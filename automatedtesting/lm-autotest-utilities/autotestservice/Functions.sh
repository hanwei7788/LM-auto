thisdir=$(dirname $(realpath $0))

##############
#Quit function
##############
quit_clean () {
  echo no > $devicefolder/autotestson.txt
  exit $1
}
##########################
#Send CAN message function
##########################
can_message () {
  command=$1
  if [[ $command == "poweroff" ]]; then
    if [[ $software_type == "pallas" ]]; then
      bash $scriptfolder/SendCANMessage.sh $name $interface "KeyPosition=0"
    elif [[ $software_type == "argo" ]]; then
      bash $scriptfolder/SendCANMessage.sh $name $interface "vehiclePowerMode=0"
    elif [[ $software_type == "indy" ]]; then
      bash $scriptfolder/SendCANMessage.sh $name $interface "chargingInd=0 readyInd=0"
    else
      #Add command for other software_types
      echo "Another software type"
    fi
  elif [[ $command == "poweron" ]]; then
    if [[ $software_type == "pallas" ]]; then
      bash $scriptfolder/SendCANMessage.sh $name $interface "KeyPosition=3"
    elif [[ $software_type == "argo" ]]; then
      bash $scriptfolder/SendCANMessage.sh $name $interface "vehiclePowerMode=3"
    elif [[ $software_type == "indy" ]]; then
      bash $scriptfolder/SendCANMessage.sh $name $interface "chargingInd=1 readyInd=1"
    else
      #Add command for other software_types
      echo "Another software type"
    fi
  fi
  #Add new commands here if necessary
}
#############
#SSH function
#############
ssh_cmd () {
  sshpass -p $ssh_pw ssh -o StrictHostKeyChecking=no "root@$ip" $1
}

# Read JSON data from stdin and fetch an atom from there, by iterating through
# arguments and entering corresponding subelement (ie.
# `json_get_data a b c` would get "c" from "b" from "a").
# Only works with dicts, not with arrays (since the key used is always a str)
json_get_data () {
  python3 -c '
import sys, json
data = json.load(sys.stdin)
try:
  for arg in sys.argv[1:]:
    data = data[arg]
  print(data)
  sys.exit(0)
except Exception as e:
  print("%s: %s" % (type(e).__name__, e), file=sys.stderr)
  sys.exit(1)' $@

  return $?
}

get_config_param () {
  json_get_data $@ < $(dirname $thisdir)/common/config.json
}

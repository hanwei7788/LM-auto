#! /bin/bash

# TIPS AND TRICKS
# if a measurement point is missing from some log (because a certain image
# does not produce it or whatever) and you still want to extract the other
# measurement points just add some fake line copied from another log.
# Doesn't matter where, in the beginning or end or anywhare in between
set -e
set -u
#set -x

trap errorhandler EXIT

# for each measurement point to be reported update the respective entry
# in the following 4 arrays
# indexing of the arrays is the reporting order in the reproduced
# (really this should be 1 array of structs)

# name of the measurement point
names=("uboot2kernel" "mount_root" "ui_cluster" "ui_center")
#regexp to find the correct line, passed to grep
lineexps=("elapsed=[0-9]"
          "VFS: Mounted root.*epit:"
          "org.argo-ic-ui/main.qml is now running after.*epit value:"
          "ui_center/main.qml is now running after.*epit value:")
#substitution to get the value, passed to sed
valueexps=("s/\(.*\)elapsed=\([0-9][0-9]*\)\(.*\)/\2/"
           "s/\(.*epit: \)\([1-9][0-9]*\)\(.*\)/\2/"
           "s/\(.*epit value: \)\([1-9][0-9]*\)\(.*\)/\2/"
           "s/\(.*epit value: \)\([1-9][0-9]*\)\(.*\)/\2/")
#time conversion function
convfuncs=("us2ms" "epit2ms" "epit2ms" "epit2ms")

function errorhandler {
  echo "*Error*: Internal/unexpected error, you might need \"set -x\" to debug..." 2>/dev/null
}

function clear_errorhandler {
  trap "" EXIT
}

function isint {
  if [[ "$1" =~ ^[0-9]+$ ]]
  then
    echo true
  else
    echo false
  fi
}

# precondition: argument has been tested before to be an int
function us2ms {
  ns=$1
  shifted=$((ns / 100))
  deci=$((shifted % 10))
  shifted=$((shifted / 10))
  if [[ $deci -ge 5 ]]
  then
    : $((shifted++))
  fi
  echo $shifted
}

# precondition: argument has been tested before to be an int
function epit2ms {
  ms=$((0xFFFFFFFF - $1))
  echo $(us2ms $ms)
}

if [[ -n ${unittest:-} ]]
then
  return 0
fi

if [[ $# -ne 1 ]]
then
  echo "Usage $0 <logfile>" >&2
  clear_errorhandler
  exit 1
else
  infile="$1"
fi
outfile="${infile}.csv"
if [[ -e "$outfile" ]]
then
  echo "*Error* Output file $outfile already exists" >&2
  clear_errorhandler
  exit 2
fi

last=0
i=-1
while [[ $((++i)) -lt ${#lineexps[*]} ]]
do
  set +e
  hits=$(grep -c "${lineexps[i]}" $infile)
  set -e
  if [[ $hits -ne 1 ]]
  then
    echo "*Error*: Unexpected log contents in $infile:" >&2
    echo "         $hits occurences of measurement point ${names[i]}" >&2
    if [[ $hits -eq 0 ]]
    then
       echo "         See TIPS AND TRICKS in source code how to possibly work around this" >&2
    fi
    clear_errorhandler
    exit 2
  fi
  line=$(grep "${lineexps[i]}" $infile)
  value=$(echo "$line" | sed "${valueexps[i]}")
  inttest=$(isint "$value")
  if ! $inttest
  then
    echo "*Error*: Measurement value for ${names[i]} is..." >&2
    echo "         >>>${value}<<<" >&2
    echo "         That does not look like an integer to me" >&2

    clear_errorhandler
    exit 2
  fi
  converted=$(${convfuncs[i]} $value)
  delta=$((converted - last))
  results="${names[i]},$value,$converted,$delta"
  echo "$infile,$results"
  if [[ $i -eq 0 ]]
  then
    prefix="$infile,"
  else
    prefix=","
  fi
  echo -n "$prefix$results" >>$outfile
  last=$converted
done
echo >>$outfile

clear_errorhandler

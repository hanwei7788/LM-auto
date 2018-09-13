#! /bin/bash
if [[ $# -ne 1 ]]
then
  echo "Usage: $0 <dmesg-output>" 2>/dev/null
  exit 1
fi
logfile=$1
mydir=$(dirname $0)

awk -f ${mydir}/initcall.awk $logfile | sort -n

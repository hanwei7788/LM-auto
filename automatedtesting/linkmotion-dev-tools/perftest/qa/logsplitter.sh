#! /bin/bash

#set -x
set -u
set -e

output=""

function switch_output {
  if [[ -z "$output" ]] || [[ "$1" =~ syslog-ng\ starting\ up ]]
  then
    output=$(next_free)
    exec >${output}
    echo "Writing to $output" >&2
  fi
}

# Known bugs: if boot-2 already exists, but boot-1 doesn't,
# the counting will be boot-1, boot-3 in the next run
function next_free {
  local format="-boot-%04d"
  local i=1
  local suffix
  printf -v suffix -- $format $i
  local output=${input}${suffix}
  while [[ -e "$output" ]]
  do
    : $((i++))
    printf -v suffix -- $format $i
    output=${input}${suffix}
  done
  echo "$output"
}

if [[ $# -ne 1 ]]
then
  echo "Usage $0 <logfile>" >&2
  exit 1
else
  input="$1"
fi

exec <"$input"
while IFS="" read -r line
do
  switch_output "$line"
  echo -E "$line"
done
if [ -n "$line" ]
then
  switch_output "$line"
  printf '%s' "$line"
fi

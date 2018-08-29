#!/bin/bash
# Run Current Test Set v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

_logfile="TestReports_$1/$2/$1-$2-log_TestRun.txt"
_xmlfile="TestReports_$1-$2-TestRun.xml"

cd "${autotest_root}/c4c-functional-tests"

# Fetch test set template from DAV

curl -k -u linkmotion@nomovok.com:5pHgunweds -o "$_xmlfile" "${test_set_template_path}${current_test_base}"

printf "local: ${_xmlfile}\n"
printf "remote: ${test_set_template_path}${current_test_base}\n"

if [ ! $? -eq 0 ]
then
  printf "Test set retrieval error\n"
  exit 1
else
  printf "Test set retrieval OK\n"
fi

if [ ! -s "${_xmlfile}" ]
then
  printf "XML file size zero\n"
  exit 1
fi
test_options="--sut_config=${1} --test_run_id=${2}"
rake run_xml["$_xmlfile"] TESTOPTS="${test_options}" > "$_logfile"

exit 0

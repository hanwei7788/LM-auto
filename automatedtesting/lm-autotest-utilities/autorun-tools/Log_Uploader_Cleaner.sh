#!/bin/bash
# Upload logs/reports to DAV and move to archive locations v1
#
# Cron logs - OK
# Test run XML files - OK
# Test run log files - OK
# Test result folder
#   - Compressed and copied to "uploader" folder by test result script, 
#   - Uploaded to DAV 
#   - Deleted from separate folder when uploaded.
#   - Original results folder untouched
# Test comparison results - OK

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

TESTRUNFLAG="${autotest_root}/c4c-functional-tests/TestReports_$1/TestRunOn"

if [ -f "${TESTRUNFLAG}" ]
then
  printf "Test run in progress - not moving logs\n"
  exit 1
fi

shopt -s nullglob

# Upload results to DAV and move to "${autotest_root}/upload_log_archive"
# Cron logs

printf "Start upload\n"

cd "${autotest_root}/c4c-functional-tests/TestReports_$1/$2"
cron_logs=(*cron.log)
printf '%s\n' "${cron_logs[@]}"

for i in "${cron_logs[@]}"
do
  if [ -f "${TESTRUNFLAG}" ]
  then
    exit 1
  fi
  printf "Upload: $i\n"
  curl -k -T "$i" -u linkmotion@nomovok.com:5pHgunweds "${test_results_path}/cron_logs/"
done

# Test run log files
cd "${autotest_root}/c4c-functional-tests/TestReports_$1/$2"
test_log=(*log_TestRun.txt)
printf '%s\n' "${test_log[@]}"

for i in "${test_log[@]}"
do
  if [ -f "${TESTRUNFLAG}" ]
  then
    exit 1
  fi
  printf "Upload: $i\n"
  curl -k -T "$i" -u linkmotion@nomovok.com:5pHgunweds "${test_results_path}/"
done

# Test run comparison files
cd "${autotest_root}/c4c-functional-tests/TestReports_$1/$2"
comparison_log=(*comparison_log.txt)

for i in "${comparison_log[@]}"
do
  if [ -f "${TESTRUNFLAG}" ]
  then
    exit 1
  fi
  printf "Upload: $i\n"
  curl -k -T "$i" -u linkmotion@nomovok.com:5pHgunweds "${test_results_path}"
done

# Test run XML files
# cd "${autotest_root}/c4c-functional-tests/TestReports_$1/$2"
cd "${autotest_root}/c4c-functional-tests"
test_xml="TestReports_$1-$2-TestRun.xml"
printf "Upload: ${test_xml}\n"
curl -k -T "${test_xml}" -u linkmotion@nomovok.com:5pHgunweds "${test_results_path}/"

# Test report compressed archives
# Compress all results
cd "${autotest_root}/c4c-functional-tests"
current_results="TestReports_$1/$2"
tar -zcvf "${autotest_root}/lm-autotest-utilities/autorun-tools/uploader/$1-$2.tar.gz" "$current_results"

# Upload archives
report_archive="${autotest_root}/lm-autotest-utilities/autorun-tools/uploader/$1-$2.tar.gz"
printf "Upload: ${report_archive}\n"
curl -k -T "${report_archive}" -u linkmotion@nomovok.com:5pHgunweds "${test_results_path}/"
rm ${report_archive}

printf "Stop upload\n"
exit 0

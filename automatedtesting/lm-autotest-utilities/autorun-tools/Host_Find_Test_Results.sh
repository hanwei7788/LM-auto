#!/bin/bash
# Find Current Test Run Results and run comparison v1

source "$HOME/automatedtesting/c4c-functional-tests/TestReports_$1/image.conf"

cd "${autotest_root}/c4c-functional-tests/TestReports_$1"

cat CurrentTestRun.txt > PreviousTestRun.txt

# find "TestReports_${sut_config}" -maxdepth 1 -type d -iname "[0-9]*" | sort -r | head -1 > CurrentTestRun.txt
printf "TestReports_$1/$2\n" > CurrentTestRun.txt

previous_results=$(head -1 PreviousTestRun.txt)
previous_results_sut=$(cut -d"/" -f1 PreviousTestRun.txt)
previous_results_folder=$(cut -d"/" -f2 PreviousTestRun.txt)
current_results="TestReports_$1/$2"
current_results_sut="TestReports_$1"
current_results_folder="$2"
diff_dir="$(mktemp -d)"

# Debug prints
printf "Previous: $previous_results\n"
printf "Previous SUT: $previous_results_sut\n"
printf "Previous Folder: $previous_results_folder\n"
printf "Current: $current_results\n"
printf "Current SUT: $current_results_sut\n"
printf "Current Folder: $current_results_folder\n"
printf "Directory for test output diffs: $diff_dir\n"

comparison_log="../TestReports_$1/$2/$1-$2-comparison_log.txt"
printf "Comparison Log: $comparison_log\n"

printf "Previous: $previous_results\n" > "$comparison_log"
printf "Current: $current_results\n" >> "$comparison_log"
printf "Log start:\n" >> "$comparison_log"


../compare_test_results.rb "../${previous_results}/xray_report.json"  "../${current_results}/xray_report.json" "$diff_dir" >> "$comparison_log"


exit 0





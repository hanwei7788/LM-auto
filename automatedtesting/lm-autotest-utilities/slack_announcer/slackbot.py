#!/usr/bin/python

import string
import sys
import json
import subprocess
import os

#WebHook of the channel the message is sent to
hook="<REPLACE THIS WITH THE HOOK>"
HOME = "/home/autotest"

# Send slack message to a channel configured in the hook. Hook configurations are done in Slack
#Script takes 2 parameters: 1. sut name and 2. testrun ID
def main():

	if(len(sys.argv) != 3):
		print("\n usage: ./slackbot.py <sut_name> <test_run_ID> \n")
		sys.exit(2)

	sut_name = str(sys.argv[1])
	test_id = str(sys.argv[2])

	testfolder_path = HOME + "/automatedtesting/argo_functional_tests/TestReports_" + sut_name + "/" + test_id

	if not os.path.isdir(testfolder_path) or not os.path.exists(testfolder_path + "/issue_key.json"):
		print("Unable to find test folder")
		sys.exit(1)

	message = "Smoke test run for "
	message += sut_name

	#Fetch the issue key generated in Jira upload
	with open(testfolder_path + "/issue_key.json") as data_file:
		issue_data = json.load(data_file)
		issue_key = issue_data['key']

	if not issue_key:
                print("Unable to get the JIRA issue key for this test run")
                sys.exit(1)
	
	url = "https://jira.link-motion.com/browse/" + issue_key

	message += ". Test results in: " + url
	# Send a message to #<???> channel
	cmd = 'curl -X POST -H \"Content-type: application/json\" --data ' + '\'' + '{ \"text\":\"'  + message + '\" }' + '\''
	cmd += " " + hook

	subprocess.call(cmd, shell=True)

if __name__ == "__main__":
	main()

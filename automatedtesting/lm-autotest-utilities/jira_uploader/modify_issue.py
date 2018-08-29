#!/usr/bin/python3

#This script is modifies an existing JIRA issue. If a issue does not exist, exits.

#The script ses the issue_key.json file to find the JIRA issue key in the folder of a test run.
#Takes 2 parameters:
#	1. sut name
#	2. test run ID

from upload import *
import json
import sys
import uploader_common

HOME = "/home/autotest/"
sut_name = ""
argotestroot = HOME + "automatedtesting/argo_functional_tests"
test_id = ""
issue_key = ""
uploader_path = HOME + "automatedtesting/lm-autotest-utilities/jira_uploader"
testfolder_path = ""
username = ""
pw = ""

def modify():
	print("Importing to issue:", issue_key)
	try:
		import_issue(username, pw, testfolder_path)
	except:
		raise JiraException("**Unable to POST to JIRA**")

def fetch_issue_key():
	print("Fetching JIRA issue key")

	global issue_key

	try:
		issue_key_data = read_json(testfolder_path + "/issue_key.json")
	except FileNotFoundError:
		print("File \"issue_key.json\" not found")
		raise JiraException("**Could not find issue_key file from", testfolder_path)
	try:
		issue_key = issue_key_data['key']
	except KeyError:
		raise JiraException("**Could not fetch JIRA issue key**")

	append = {"testExecutionKey":issue_key}

	try:
		data = read_json(testfolder_path + "/xray_report.json")
	except FileNotFoundError:
		print("File \"xray_report.json\" not found")
		raise JiraException("**Could not find xray_report file from", testfolder_path)

	data.update(append)
	dump_to_file(testfolder_path + "/xray_report.json", data)

def main():

	if(len(sys.argv) != 3):
		print("\n usage: ./modify_issue.py <sut_name> <test_run_ID> \n")
		sys.exit(2)

	global sut_name, test_id, username, pw, testfolder_path

	sut_name = str(sys.argv[1])
	test_id = str(sys.argv[2])
	testfolder_path = argotestroot + "/TestReports_" + sut_name + "/" + test_id

	try:
		username, pw = uploader_common.get_jira_auth()
	except (FileNotFoundError, json.decoder.JSONDecodeError, KeyError) as e:
		print("Error when reading auth from config:", file=sys.stderr)
		uploader_common.print_exc(e, sys.stderr)
		sys.exit(1)

	try:
		fetch_issue_key()
		modify()
		import_attachment(testfolder_path + "/" + sut_name + "-" + test_id + "-cron.log", issue_key)
		import_attachment(testfolder_path + "/" + sut_name + "-" + test_id + "-log_TestRun.txt", issue_key)

	except (JiraException) as err:
		print("error:", err)
		print("Abort JIRA modification")
		sys.exit(1)

main()

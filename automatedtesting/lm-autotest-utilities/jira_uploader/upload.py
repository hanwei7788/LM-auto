#!/usr/bin/python3

#This is a JIRA uploader script that is supposed to be used with autotesting
#Script creates a new issue in JIRA, receives a issue Key in that process and
#uploads results of a autotest run to this issue.

import json
import os
import subprocess
import sys
from string import Template
import time
import datetime
import uploader_common

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(my_path() + "/../common")
import jiralib
import global_config

uploader_path = my_path()
DEFAULT_CONF_FILE = os.path.join(uploader_path, "jira_upload_conf.json")
WEEK = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']

projects = { "argo":"LM", "pallas":"PLL", "XTP":"XTP", "FOS":"TPTT", "indy":"INDY" }

cmdline_args = [
	(("-n", "--sut_name"), {
	"help": "Name of the target system under test (SUT)",
	"required": True,
	}),
	(("-t", "--test_id"), {
	"help": "Autotest ID",
	"required": True,
	}),
	(("-c", "--conf"), {
	"help": "(Optional) Configuration file URL. Default: %s" % DEFAULT_CONF_FILE,
	"default": DEFAULT_CONF_FILE,
	})
]

class JiraException(Exception):
	pass

class FileException(Exception):
	pass

def upload_attachments(jira, issue_key, testfolder_path, sut_name, test_id, conf_file):
	attachments = os.path.join(testfolder_path, "attachments.json")
	with jiralib.MultipleFileManager() as fm:
		fm.add_file(os.path.join(testfolder_path, sut_name + "-" + test_id + "-cron.log"))
		fm.add_file(os.path.join(testfolder_path, sut_name + "-" + test_id + "-log_TestRun.txt"))
		conf = uploader_common.read_json(conf_file)
		graphs = conf["graphs"]
		for graph in graphs:
			fm.add_file(os.path.join(testfolder_path, graph))
		result_attachments = jira.upload_files(issue_key, fm)
		uploader_common.dump_to_file(attachments, result_attachments)

def import_xray(jira, issue_key, testfolder_path):
	#Append the new issue_key into the test result xray_report.json
	xray_file = os.path.join(testfolder_path, "xray_report.json")
	data = uploader_common.read_json(xray_file)
	data["testExecutionKey"] = issue_key
	uploader_common.dump_to_file(xray_file, data)
	jira.import_xray(issue_key, xray_file)

def modify_template(sut_name, sutfolder_path, testfolder_path):
	print("Fetching", sut_name, "image information")
	image_url = uploader_common.read_file(os.path.join(sutfolder_path, "last_installed_zip.txt")).strip()
	image_name = os.path.basename(image_url)

	date = (time.strftime("%d.%m.%Y"))
	day = datetime.datetime.today().weekday()
	weekday = WEEK[day]
	version = image_name.split("-")[1]

	content = uploader_common.read_file(os.path.join(sutfolder_path, "image.conf"))
	paths = content.splitlines()
	for path in paths:
		p = path.split("=", 1)
		if(p[0] == "hardware"):
			hardware = p[1]
		elif(p[0] == "software_type"):
			software_type = p[1]
		elif(p[0] == "test"):
			test = p[1]
		elif(p[0] == "test_plan"):
			testplan = p[1]

	d = { 'image_url':image_url, 'date':date, 'software_type':software_type, \
		'sut_name':sut_name, 'version':version, 'hardware':hardware, 'weekday':weekday, \
		'testplan':testplan }
	print(d)
	#Checking which project type is under testing. This decides which template file is used to
	#and in which project the JIRA issue will be created
	try:
		project = projects[software_type]
	except KeyError:
		raise JiraException("**No project specified for the SUT**")

	#Reading the template project issue creation file and appending this file with information
	#fetched from the image.conf file.
	if not test:
		path = os.path.join(uploader_path, "templates", \
					"issue_template_" + project + ".json")
	else:
		path = os.path.join(uploader_path, "templates", \
					"issue_template_" + project + "_" + test + ".json")

	#Open template file and fill in the blanks
	filein = uploader_common.read_file(path)
	issue_template = Template(filein)
	issue_result = issue_template.substitute(d)
	issue = json.loads(issue_result, strict=False)

	return issue

def create_issue(sut_name, jira, sutfolder_path, testfolder_path):

	issue_data = modify_template(sut_name, sutfolder_path, testfolder_path)
	print("Creating JIRA issue")
	#Creates a issue_key.json file in the testfolder. If already exists, writes over
	try:
		retjson = jira.create_issue(issue_data)
	except jiralib.JIRAException as e:
		raise JiraException("Could not create JIRA issue:", e)
	try:
		issue_key = retjson["key"]
		key_file = os.path.join(testfolder_path, "issue_key.json")
		uploader_common.dump_to_file(key_file, retjson)

	except KeyError as e:
		raise JiraException("Key %s missing from JIRA issue create response" % e)

	return issue_key

#This function is to see if the necessary files exist. If not, does not create a new issue in jira
def check_xray_report(testfolder_path):
	xray_path = os.path.join(testfolder_path, "xray_report.json")
	print(xray_path)
	if not os.path.exists(xray_path):
		raise FileException("Could not find xray_report file in path:", testfolder_path)

def upload(sut_name, test_id, conf_file):
	try:
		jira_auth = uploader_common.get_jira_auth()
	except (FileNotFoundError, json.decoder.JSONDecodeError, KeyError) as e:
		print("Error when reading auth from config:", file=sys.stderr)
		uploader_common.print_exc(e, f=sys.stderr)
		sys.exit(1)

	jira_url = global_config.get_conf("urls", "jira")
	jira = jiralib.JIRA(jira_url, jira_auth)
	argotestroot = uploader_common.get_path_from_conf("argotest", conf_file)

	sutfolder_path = os.path.join(argotestroot, "TestReports_" + sut_name)
	testfolder_path = os.path.join(sutfolder_path, test_id)

	print("Initiating JIRA uploader...")
	try:
		check_xray_report(testfolder_path)
		issue_key = create_issue(sut_name, jira, sutfolder_path, testfolder_path)
		import_xray(jira, issue_key, testfolder_path)
		upload_attachments(jira, issue_key, testfolder_path, sut_name, test_id, conf_file)

	except  (JiraException, FileException) as err:
		print("error:", err)
		print("Aborting JIRA upload")
		return 1

	print("Jira upload done")
	return 0

def main(argv):
	args = uploader_common.parse_args(argv, cmdline_args)
	ret = upload(args.sut_name, args.test_id, args.conf)
	sys.exit(ret)

if __name__ == "__main__":
	main(sys.argv)

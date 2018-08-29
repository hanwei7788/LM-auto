#!/usr/bin/python3

import json
import sys
import os
from string import Template
import datetime
import time
import datetime
import tempfile
import shutil
import uploader_common

HOME = os.getenv("HOME")
qatools_path = os.path.join(HOME, "automatedtesting", "qa-tools")

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "common"))
sys.path.append(os.path.join(my_path(), "..", "results_comparer"))
sys.path.append(os.path.join(qatools_path, "plotfaster"))
sys.path.append(os.path.join(qatools_path, "plotfaster", "exporter"))
import jiralib
import create_comment
import exporter
import combine_report
import global_config

uploader_path = my_path()
DEFAULT_CONF_FILE = os.path.join(my_path(), "jira_upload_conf.json")

projects = { "argo":"LM", "pallas":"PLL", "XTP":"XTP", "indy":"INDY" }
TEST_FAIL = "FAIL"
TEST_PASS = "PASS"
TEST_ABORTED = "ABORTED"
TEST_TODO = "TODO"
TEST_NOT_RUN = "NOT_RUN"
TEST_COLORS = { TEST_PASS:"#00FF40", TEST_FAIL:"#FF0000", \
		TEST_ABORTED:"#FFFF00", TEST_TODO:"#D3D3D3", TEST_NOT_RUN:"FFFFFF" }

cmdline_args = [
	(("-n", "--sut_name"), {
	"help": "Name of the target system under test (SUT)",
	"required": True,
	}),
	(("-t", "--test_id"), {
	"help": "Autotest ID",
	"required": True,
	}),
	(("-k", "--issue_key"), {
	"help": "(Optional) JIRA issue key in which the results are imported to",
	"default": None,
	}),
	(("-c", "--conf"), {
	"help": "(Optional) Configuration file URL. Default: %s" % DEFAULT_CONF_FILE,
	"default": DEFAULT_CONF_FILE,
	})
]

def combined_status(status1, status2):
	if status1 == TEST_FAIL or status2 == TEST_FAIL:
		return TEST_FAIL
	elif status1 == TEST_PASS or status2 == TEST_PASS:
		return TEST_PASS
	elif status1 == TEST_ABORTED or status2 == TEST_ABORTED:
		return TEST_ABORTED
	else:
		return TEST_TODO

def update_jira_attachments(jira, fm, master_path, issue_key, conf_file):
	attachments = os.path.join(master_path, "attachments.json")
	if os.path.exists(attachments):
		delete_attachment(jira, attachments)
	conf = uploader_common.read_json(conf_file)
	image_names = conf["graphs"]
	for image in image_names:
		fm.add_file(os.path.join(master_path, image))
	result_attachments = jira.upload_files(issue_key, fm)
	uploader_common.dump_to_file(attachments, result_attachments)

#Function to delete a attachment in a JIRA issue. Uses a attachment key generated when
#the attachment was imported in the first place. If key does not exists, HTTP request returns
#"No attachment key"
def delete_attachment(jira, file):
	attachment_file = uploader_common.read_json(file)
	for attachment in attachment_file:
		try:
			jira.delete_file(attachment["id"])
			print("Deleted attachment: name:", attachment["filename"], "id:", \
				attachment["id"])
		except JIRAException as e:
			print("Error deleting files:", e)

#Function to create a HTML file results results.html, which contains the information about
#all the autotest runs done for this image.
def create_test_table(test_table, issue_key, test_id, sut_name):
	results = uploader_common.read_json(test_table)
	cases = results["cases"]
	html = '<html><body><table border="1"><tr><td>n</td>'

	#Create header row, which contains the test LM codes
	for case in cases:
		html += "<td>{}</td>".format(case)
	html += "</tr>"
	num_test_runs = results['runs']
	for test_run in range(0, num_test_runs):
		run_count = test_run + 1
		#First cell of each column is always the number of test run
		html += "<tr>"
		html += "<td>{run}</td>".format(run = str(run_count))
		#Create cell
		for test_case in cases:
			test_result = results[test_case][test_run]
			url = "https://jira.link-motion.com/secure/XrayExecuteTest!default.jspa?testExecIssueKey=" + issue_key + "&testIssueKey=" + test_case
			#color format for cell background
			color = TEST_COLORS[test_result]
			if test_result == TEST_NOT_RUN:
				test_result = ""
			html += "<td bgcolor=\"{color}\">".format(color = color)
			html += "<a href=\"{url}\">{test_result}</a>".format(url = url, test_result = test_result)
			html += "</td>"
		#end cell
		html += "</tr>"

	#end table
	html += "</table>"

	#Extra information about SUT and latest test run
	html += "<br><span>Latest test run ID: {}</span><br>".format(test_id)
	html += "<span>SUT ID: {}</span><br>".format(sut_name)
	dt = datetime.datetime.now()
	html += "<span>Last test finished at: {}</span><br>".format(str(dt))

	#end of html file
	html += "</body></html>"

	return html

#Function to import the master_xray_report.json to the JIRA issue and update its content.
#Master_xray_report contains the "worst case scenario" results of several nightly test runs
def import_updated_xray(jira, issue_key, master_path, upload_file, test_id, sut_name):
	print("Importing issue to", issue_key)
	print("upload_file:", upload_file)
	jira.import_xray(issue_key, upload_file)
	return create_test_table(os.path.join(master_path, "tests.json"), issue_key, test_id, sut_name)

def _compare_results_new_task(master_xray, new_xray, first_xray):
	print("No master_xray_report to be found. First run for this image")
	shutil.copyfile(new_xray, master_xray)
	shutil.copyfile(new_xray, first_xray)
	return uploader_common.read_json(master_xray)

def _compare_two_xrays(master_res, new_res, results):
	print("Start comparing two xray_reports")
	new_tests = new_res['tests']
	master_tests = master_res['tests']
	runs = results['runs']

	fresh_tests = []
	for new_test in new_tests:
		new_test_key = new_test["testKey"]
		#Check if test plan contains new testcases
		fresh_tests.append(new_test_key)
		if new_test_key not in results['cases']:
			results['cases'].append(new_test_key)
			results[new_test_key] = [TEST_NOT_RUN] * runs
		else:
			results[new_test_key].append(new_test['status'])

			matched = False
			for master_test in master_tests:
				if(new_test_key == master_test['testKey']):
					master_test['status'] = combined_status(new_test['status'], master_test['status'])
					#If the test does not pass, the tests run log will be appended to the comments section in test execution details
					if(new_test['status'] != TEST_PASS):
						master_test['comment'] += new_test['comment']
					matched = True
			#If here, master test file has no new_tests test key
			if not matched:
				print("Not in master", new_test_key)
				results[new_test_key].append(new_test["status"])
				master_tests.append(new_test)

	#Last check if a test has been removed from test set, if so, NOT_RUN is for that test case
	for testcase in results["cases"]:
		if testcase not in fresh_tests:
			results[testcase].append(TEST_NOT_RUN)

	return results

#Function to compare two xray_reports. Comparison specified in documentation
def compare_results(issue_key, new_xray, master_xray, tests_json, first_xray):
	print("Starting to compare autotest results")
	try:
		results = uploader_common.read_json(tests_json)
	except FileNotFoundError:
		new_res = uploader_common.read_json(new_xray)
		new_tests = new_res['tests']
		results = {}
		results["cases"] = []
		for new_test in new_tests:
			new_test_key = new_test["testKey"]
			results[new_test_key] = []
			results["cases"].append(new_test_key)
			results[new_test_key].append(new_test['status'])
			results["runs"] = 0

	#If there is no master xray_report, the current test result can be just copied
	if not os.path.isfile(master_xray):
		master_res =_compare_results_new_task(master_xray, new_xray, first_xray)

	#otherwise the master_xray_report and newly created report have to be compared and master_xray_report is modified
	#according to specifications of which results overwrite which.
	else:
		master_res = uploader_common.read_json(master_xray)
		new_res = uploader_common.read_json(new_xray)
		results = _compare_two_xrays(master_res, new_res, results)
	print(results)
	results['runs'] += 1
	master_res['testExecutionKey'] = issue_key
	uploader_common.dump_to_file(master_xray, master_res)
	uploader_common.dump_to_file(tests_json, results)

#Function to create a new JIRA issue. This is called only if the nightly_issue_keys folder does
#not already contain this named key. Keys are named after the zip name.
def create_key(jira, image_url, argotestroot, uploader_path, sut_name):
	print("Creating new test Execution master task")

	version = ""
	hardware = ""
	testplan = ""

	image_name = image_url.split("/")[-1].strip("\n")
	version = image_name.split("-")[1]

	content = uploader_common.read_file(os.path.join(argotestroot, "TestReports_" + sut_name, "image.conf"))
	paths = content.splitlines()
	for path in paths:
		p = path.split("=", 1)
		if(p[0] == "hardware"):
			hardware = p[1]
		elif(p[0] == "software_type"):
			software_type = p[1]
		elif(p[0] == "test_plan"):
			testplan = p[1]

	project = projects[software_type]

	date = (time.strftime("%d.%m.%Y"))

	d = {'image_name':image_name, 'image_url':image_url, 'sut_name':sut_name, 'version':version, 'hardware':hardware, 'software_type':software_type, 'project':project, 'date':date, 'testplan':testplan }

	file = uploader_common.read_file(os.path.join(uploader_path, "templates", "issue_template_master.json"))
	issue_template = Template(file)
	issue_result = issue_template.substitute(d)
	issue = json.loads(issue_result, strict=False)

	return jira.create_issue(issue)

def on_test_success(issue_key, master_path, testfolder_path, jira, test_id, sut_name, new_task):
	compare_results(issue_key, \
			os.path.join(testfolder_path, "xray_report.json"), \
			os.path.join(master_path, "master_xray_report.json"), \
			os.path.join(master_path, "tests.json"), \
			os.path.join(master_path, "first_run_xray_report.json"))

	result_html = import_updated_xray(jira, issue_key, \
					master_path, \
					os.path.join(master_path, "master_xray_report.json"), \
					test_id, sut_name)
	if not new_task:
		result = combine_report.combine(uploader_common.read_bytes(os.path.join(master_path, "master_report.jsonl.zlib")), \
						uploader_common.read_bytes(os.path.join(testfolder_path, "report.jsonl.zlib")), \
						combine_report.CombineModes.DIFFERENT_BOOTS)

		with open(os.path.join(master_path, "master_report.jsonl.zlib"), 'wb') as report_file:
			report_file.write(result)

	report = uploader_common.read_bytes(os.path.join(master_path, "master_report.jsonl.zlib"))
	exporter.export(report, master_path)
	print("Exported " + master_path + "/master_report.jsonl.zlib")
	#Update attachments in Jira issue
	with jiralib.MultipleFileManager() as fm:
		with tempfile.TemporaryDirectory() as html_dir:
			html_path = os.path.join(html_dir, "result.html")
			with open(html_path, 'w') as f:
				f.write(result_html)
			fm.add_file(html_path)
			update_jira_attachments(jira, fm, master_path, issue_key, DEFAULT_CONF_FILE)

def on_new_task(testfolder_path, master_path, sut_name, test_id, issue_key, argotestroot, jira, last_installed_zip):
	with jiralib.MultipleFileManager() as fm:
		fm.add_file(os.path.join(testfolder_path, sut_name + "-" + test_id + "-cron.log"))
		fm.add_file(os.path.join(testfolder_path, sut_name + "-" + test_id + "-log_TestRun.txt"))
		jira.upload_files(issue_key, fm)
		#This is compare part, where the previous images first run and this images first run are compared.
		split_zip = last_installed_zip.split("/")[-1]
		split_zip = split_zip.split("-")
		all_dirs = os.listdir(os.path.join(argotestroot, "nightly_issue_keys"))
		same_types = []
		for item in all_dirs:
			if (split_zip[2] + "-" + split_zip[3]) in item:
				if item.endswith(".zip"):
					same_types.append(item)
		same_types.sort()
		try:
			last_image_folder = os.path.join(argotestroot, "nightly_issue_keys", same_types[-2])
		except IndexError as e:
			print("No previous test run for this image type. Skipping result comparer...", e)
			return
		if not os.path.isfile(os.path.join(last_image_folder, "first_run_xray_report.json")):
			print("No first_run_xray_report.json for last image of this type")
		else:
			create_comment.run(os.path.join(last_image_folder, "first_run_xray_report.json"), \
					os.path.join(master_path, "first_run_xray_report.json"), issue_key)
	print("Added logs as attachments")


def compare_and_upload(sut_name, test_id, conf_file=DEFAULT_CONF_FILE, key=None):
	try:
		auth = uploader_common.get_jira_auth()
	except (FileNotFoundError, json.decoder.JSONDecodeError, KeyError) as e:
		print("Error when reading auth from config:", file=sys.stderr)
		uploader_common.print_exc(e, f=sys.stderr)
		return 1

	new_task = False

	jira_url = global_config.get_conf("urls", "jira")
	jira = jiralib.JIRA(jira_url, auth)

	argotestroot = uploader_common.get_path_from_conf("argotest", conf_file)
	sutfolder_path = os.path.join(argotestroot, "TestReports_" + sut_name)
	testfolder_path = os.path.join(sutfolder_path, test_id)

	if not os.path.isdir(testfolder_path):
		print("Unable to find testfolder", testfolder_path, "\nExiting...")
		return 1

	last_installed_zip_url = uploader_common.read_file(os.path.join(sutfolder_path, \
							"last_installed_zip.txt")).strip()
	last_installed_zip = os.path.basename(last_installed_zip_url)
	master_path = os.path.join(argotestroot, "nightly_issue_keys", last_installed_zip)
	zip_key_file = os.path.join(master_path, last_installed_zip + "_key.json")

	if not key:
		if os.path.exists(zip_key_file) == False:
			print("No issue key for this image")
			os.makedirs(master_path, exist_ok=True)
			issue_key_json = create_key(jira, last_installed_zip_url, \
							argotestroot, \
							uploader_path, sut_name)
			uploader_common.dump_to_file(zip_key_file, issue_key_json)
			shutil.copyfile(os.path.join(testfolder_path, "report.jsonl.zlib"), \
						os.path.join(master_path, "master_report.jsonl.zlib"))
			new_task = True

		key = uploader_common.get_issue_key(zip_key_file)
	#Now we have the key, lets start comparing the current xray_report to the master_xray_report

	#If the test run does not contain the xray_report file, something has gone wrong, but the
	#test results are imported to the issue as empty
	if not os.path.isfile(os.path.join(testfolder_path, "xray_report.json")):
		#send a comment to issue that something has gone wrong
		jira.upload_comment(key, \
			"Unable to run autotests. Check logs for more information")
	else:
		on_test_success(key, master_path, testfolder_path, jira, \
			test_id, sut_name, new_task)

	if new_task:
		on_new_task(testfolder_path, master_path, sut_name, test_id, key, argotestroot,\
				jira, last_installed_zip)

def main(argv):
	args = uploader_common.parse_args(argv, cmdline_args)
	ret = compare_and_upload(args.sut_name, args.test_id, args.conf, args.issue_key)
	sys.exit(ret)

if __name__ == "__main__":
	main(sys.argv)

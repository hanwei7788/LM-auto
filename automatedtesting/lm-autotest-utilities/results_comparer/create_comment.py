#!/usr/bin/env python3

import os
import sys
import json
import requests
import tempfile
import subprocess

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "common"))
import jiralib
import global_config

USAGE			= "Usage: %s <old_json> <new_json> <JIRA issue>"
COMPARER_SCRIPT		= os.path.join(my_path(), "compare_test_results.rb")
JIRA_URL		= "https://jira.link-motion.com/"

# All the exceptions handle the same, so no point in creating separate
# exception classes for each
class ComparerException(Exception):
	pass

def to_utf8(b_str):
	return b_str.decode("UTF-8")

def run_process(cmd):
	proc = subprocess.Popen(cmd,
	                        stdout=subprocess.PIPE,
	                        stderr=subprocess.PIPE)

	out, err = proc.communicate()
	return (out, err, proc.returncode)

# Writes per-issue diff files to diff_dir and gives the comment string as
# return value
def get_compare_comment(old, new, diff_dir):
	cmd = [COMPARER_SCRIPT, old, new, diff_dir]
	out, err, rv = run_process(cmd)
	if (rv != 0):
		raise ComparerException("Comparer failed: " + to_utf8(err))
	else:
		return to_utf8(out)

def upload_diffs(jira, issue, diff_dir):
	with jiralib.MultipleFileManager() as fm:
		fm.add_directory(diff_dir)
		jira.upload_files(issue, fm)

# Returns tuple (username, password) for use with requests
def read_auth():
	try:
		jira_auth = global_config.get_conf("auth", "jira")
		return (jira_auth["username"], jira_auth["password"])

	except KeyError as e:
		raise ComparerException("No key %s in global config" % repr(e))

def read_params():
	NUM_ARGS = 3
	argv = sys.argv
	if (len(argv) != NUM_ARGS + 1):
		raise ComparerException(USAGE % argv[0])
	else:
		return (argv[1], argv[2], argv[3])

def run(old, new, issue):
	auth = read_auth()
	jira = jiralib.JIRA(JIRA_URL, auth)

	with tempfile.TemporaryDirectory() as diff_dir:
		comment = get_compare_comment(old, new, diff_dir)
		upload_diffs(jira, issue, diff_dir)
		jira.upload_comment(issue, comment)

def main():
	try:
		old, new, issue = read_params()
		run(old, new, issue)
	except (jiralib.JIRAException, ComparerException) as e:
		print(e, file=sys.stderr)

if (__name__ == "__main__"):
	main()

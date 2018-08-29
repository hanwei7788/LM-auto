#!/usr/bin/env python3

import os
import sys
import json

def my_path(): return os.path.dirname(os.path.realpath(sys.argv[0]))
sys.path.append(my_path() + "/../common")

import jiralib
import global_config

def usage(argv):
	print("Usage: %s <issue key>" % argv[0])

def get_jira_auth(conf):
	auth = conf["auth"]["jira"]
	username = auth["username"]
	password = auth["password"]
	return (username, password)

def main(argv):
	try:
		key = argv[1]
	except IndexError:
		usage(argv)
		return 1

	with open(global_config.get_path(), "r") as f:
		conf = json.load(f)

	auth = get_jira_auth(conf)
	jira_url = conf["urls"]["jira"]

	jira = jiralib.JIRA(jira_url, auth)
	issue = jira.get_issue(key)
	print(json.dumps(issue, sort_keys=True, indent=4))
	return 0

if (__name__ == "__main__"):
	sys.exit(main(sys.argv))

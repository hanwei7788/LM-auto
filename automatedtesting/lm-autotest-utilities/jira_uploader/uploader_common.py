#!/usr/bin/python3

import os
import sys
import json
import string
import argparse

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "common"))
import global_config

def get_jira_auth():
	jira_auth = global_config.get_conf("auth", "jira")
	return (jira_auth["username"], jira_auth["password"])

def print_exc(e, f = sys.stdout):
	print("%s: %s" % (type(e).__name__, e), file=f)

def get_url_from_conf(server, file):
	conf_data = read_json(file)
	return conf_data["url"][server]

def get_path_from_conf(path, file):
	conf_data = read_json(file)
	return conf_data["paths"][path]

def read_json(file):
	with open(file, 'r') as file:
		return json.load(file)

def dump_to_file(file, data):
	with open(file, 'w') as f:
		json.dump(data, f)

def read_file(file):
	with open(file, 'r') as f:
		return f.read()

def get_issue_key(file):
	data = read_json(file)
	return data["key"]


def read_bytes(file):
	with open(file, "rb") as f:
		return f.read()


def parse_args(args, cmdline_args):
	parser = argparse.ArgumentParser()
	for arg_n, arg_p in cmdline_args:
		parser.add_argument(*arg_n, **arg_p)
	parsed = parser.parse_args(args[1:])
	return parsed

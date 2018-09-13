import os
import sys
import json

GLOBAL_CONF_FILE_NAME = "config.json"

def my_path():
	return os.path.dirname(os.path.realpath(__file__))

def get_path():
	return os.path.join(my_path(), GLOBAL_CONF_FILE_NAME)

def get_conf(*traversal_path):
	with open(get_path()) as f:
		conf = json.load(f)

	for subatom in traversal_path:
		conf = conf[subatom]

	return conf

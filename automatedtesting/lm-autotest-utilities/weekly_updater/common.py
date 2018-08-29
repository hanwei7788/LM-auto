#!/usr/bin/env python3

import os
import io
import sys
import json
import time
import datetime
import configparser
import subprocess

def my_path():
	return os.path.dirname(os.path.realpath(__file__))

sys.path.append(os.path.join(my_path(), "..", "common"))
import global_config

TIMESTAMP_FORMAT = "%y%m%d_%H%M%S"

# How often we try to update, in seconds
UPDATE_CYCLE_PERIOD	= 60 * 60

# How long to wait in long timer loops before rechecking time
LONG_SLEEP_DELAY	= 60

CONFIG_LIST_SEPARATOR	= ","
SCHEDULE_FLAG_SEPARATOR	= "-"

ZIP_EXTENSION		= ".zip"
UPDATE_LOCK_FILE	= os.path.join(my_path(), "update.lock")
CONFIG_FILE		= os.path.join(my_path(), "weekly.conf")
CONFIG_FILE_TEMPLATE	= os.path.join(my_path(), "weekly.conf.example")

TDTOOL			= "tdtool"
CAN_SIMULATOR		= os.path.join(os.environ["HOME"],
                                       "automatedtesting",
                                       "can-simulator-ng",
                                       "can-simulator-ng")

# Old autoupdate service scripts, at SCRIPT_DIR_REL
SCRIPT_DIR		= "scripts"
PREPARE_FLASHING_SCRIPT	= "prepare_flashing.sh"
START_AUTOTESTS_SCRIPT	= "run_weekly_tests.sh"
CHECK_SCHEDULE_SCRIPT	= "scheduler/scheduler.sh"

LOG_FILE = "update.log"

class ProcOutput():
	stdout = ""
	stderr = ""
	retval = 0

class FileLock():
	def __init__(self, fname = None):
		if(fname == None):
			fname = os.path.join(my_path(), UPDATE_LOCK_FILE)

		self.fname = fname
		self._fd = None
		self.pid = os.getpid()

	def __enter__(self):
		return self

	def __exit__(self, exc_type, exc_value, traceback):
		self.release()

		# If exit was caused by an exception, return False to not
		# suppress the exception
		return exc_type == None

	def acquire(self):
		try:
			flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
			content = bytearray(str(self.pid) + "\n", "ASCII")
			self._fd = os.open(self.fname, flags)
			os.write(self._fd, content)
			return True

		except OSError as e:
			self._fd = None
			if(e.errno == errno.EEXIST):
				return False
			else:
				raise

	def release(self):
		if(self._fd):
			try:
				os.close(self._fd)
				os.remove(self.fname)
			finally:
				self._fd = None

def my_path():
	return os.path.dirname(os.path.realpath(__file__))

class RunShError(Exception):
	def __init__(self, content):
		self.content = content

	def __str__(self):
		return "stdout: %s\nstderr:%s" % (self.content.stdout.decode("utf-8"),
		                                  self.content.stderr.decode("utf-8"))

class SigTermCaught(Exception):
	pass

def error(msg):
	if(isinstance(msg, bytes)):
		msg_str = msg.decode("UTF-8")
	else:
		msg_str = str(msg)
	log("Error: " + msg_str)

# Empty atoms must be separately handled to result in an empty list
def config_get_list(config, section, option):
	value = config.get(section, option)
	if(value.strip() == ""):
		return []
	else:
		return value.split(CONFIG_LIST_SEPARATOR)

def config_set_list(config, section, option, value_list):
	value = CONFIG_LIST_SEPARATOR.join(map(str, value_list))
	config.set(section, option, value)

def gen_run_sh_cmd(script, params):
	assert(isinstance(params, list))
	script_path = os.path.join(my_path(), SCRIPT_DIR, script)
	cmd = ["bash", script_path] + list(map(str, params))
	return cmd

# Will run "bash script $param1 $param2 $param3 ..."
# Returns ProcOutput instance
def run_sh(script, params, raise_on_err = True):
	cmd = gen_run_sh_cmd(script, params)
	return run_cmd(cmd, raise_on_err)

def remote_cmd(device, cmd, raise_on_err = True, timeout = None):
	my_cmd = ["sshpass", "-p", "skytree", "ssh", "root@" + device.ip] + cmd
	return run_cmd(my_cmd, raise_on_err, timeout)

def run_cmd(cmd, raise_on_err = True, timeout = None):
	p = run_nowait(cmd)
	output = ProcOutput()

	try:
		output.stdout, output.stderr = p.communicate(timeout=timeout)
	except subprocess.TimeoutExpired:
		p.kill()
		output.stdout, output.stderr = p.communicate()

	output.retval = p.returncode
	if(output.retval and raise_on_err):
		raise RunShError(output)
	else:
		return output

def run_nowait(cmd):
	return subprocess.Popen(cmd,
	                        stdin=subprocess.PIPE,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE)

# Removes leading tabs from config before feeding it to ConfigParser
def read_config(fname):
	config = configparser.ConfigParser()
	with open(fname, "r") as f:
		cdata = io.StringIO("\n".join(line.strip() for line in f))
	config.readfp(cdata)
	return config

def write_config(config, fname):
	with open(fname, "w") as f:
		config.write(f)

def log(msg):
	timestamp = time.strftime(TIMESTAMP_FORMAT,
	                          time.localtime(now_ts()))

	for line in msg.splitlines():
		print("%s: %s" % (timestamp, line))

def int_nothrow(value):
	try:
		return int(value)
	except ValueError:
		return 0

def now_ts():
	return int(time.time())

def get_auth(site):
	with open(global_config.get_path(), "r") as f:
		config = json.load(f)

	found = config["auth"][site]
	return (found["username"], found["password"])

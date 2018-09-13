#!/usr/bin/env python3

import os
import sys
import signal
import subprocess

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "common"))
import qa_common

errmsg_no_pids = "Detected no instance of Plotfaster, nothing to do"
errmsg_kill_fail = "Could not kill process %i: %s"

ip_arg = b"-T"
prompt = "> "

class NoTestNameError(Exception):
	pass

def get_pids(pidfile_path):
	try:
		with open(pidfile_path, "rb") as f:
			with qa_common.FileLocker(f):
				return qa_common.PIDRegisterer.read_pids_from_file(f)
	except FileNotFoundError:
		return []

def conv_int(x):
	try:
		return int(x)
	except ValueError:
		return 0

def get_number(start, end):
	while True:
		num = conv_int(input(prompt))
		if(num in range(start, end + 1)):
			return num

def ask_which_test(tests):
	# List of reporter pids sorted by their corresponding test names
	pids = []

	print("Following tests are running, which one do you want to end?\n")

	# Remember to convert from zero to one based index and back
	num = 1
	for name in sorted(tests.keys()):
		pids.append(tests[name])
		print("%i: %s" % (num, name))
		num += 1

	which = get_number(1, len(pids)) - 1
	return pids[which]

def extract_test_name(f, pid):
	cmdline = f.read().split(b"\x00")
	for i, arg in enumerate(cmdline):
		if(arg != ip_arg):
			continue

		target_ip = cmdline[i + 1].decode("utf-8")
		test_name = qa_common.generate_test_name(target_ip, int(pid))
		return test_name

	raise NoTestNameError(pid)

def get_test_name(pid):
	path = "/proc/%s/cmdline" % pid
	try:
		with open(path, "rb") as f:
			return extract_test_name(f, pid)

	except FileNotFoundError:
		raise NoTestNameError(pid) from None

def unlist_pid(fpath, pid):
	with open(fpath, "r+b") as f:
		with qa_common.FileLocker(f, write=True):
			pids = qa_common.PIDRegisterer.read_pids_from_file(f)
			if (pid in pids):
				pids.remove(pid)

			qa_common.PIDRegisterer.write_pids_to_file(f, pids)

def main():
	pidfile_path = os.path.join(qa_common.PLOTFASTER_PID_FILE_DIR,
	                            qa_common.PLOTFASTER_PID_FILE_NAME)
	tests = {}
	pids = get_pids(pidfile_path)

	for pid in pids:
		try:
			test_name = get_test_name(pid)
			tests[test_name] = pid

		except NoTestNameError as e:
			qa_common.log("Warning: No pid %i running, removing from pid list" % pid)
			unlist_pid(pidfile_path, pid)

	if(pids == []):
		qa_common.error(errmsg_no_pids)
		return 1

	try:
		pid = ask_which_test(tests)
		os.kill(pid, signal.SIGTERM)
		print("Ended test execution")
		return 0
	except EOFError:
		return 0

	except Exception as e:
		qa_common.error(errmsg_kill_fail % (pid, e))
		return 1

if __name__ == "__main__":
	try:
		sys.exit(main())
	except KeyboardInterrupt:
		sys.exit(1)

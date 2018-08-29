#!/usr/bin/env python3

'''
* \file
* \brief execute_test.py automatic endurance testing and monitoring script
* 
* Copyright of Link Motion Ltd. All rights reserved. 
* 
* Contact: info@link-motion.com 
* 
* \author Pauli Oikkonen <pauli.oikkonen@link-motion.com> 
* 
* any other legal text to be defined later 
'''

import sys
import json
import zlib
import os

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "common"))
import qa_common

from reporter import reporter
from exporter import exporter

# Make the loop terminate on parent (sshd) termination, because otherwise the
# stress loops would be re-parented by init once the SSH connection dies
# (forcing us to actually track PIDs on remote device).
stress_script = "while [ -d /proc/$PPID ] ; do : ; done"

logfile = "testrun.log"
cmdline_args = [
	(("-T", "--target_ip"), {
		"help": "target IP for login",
		"required": True,
	}),
	(("-u", "--username"), {
		"help": "username for login",
		"default": "root",
	}),
	(("-p", "--password"), {
		"help": "password for login",
		"default": "skytree",
	}),
	(("-s", "--stress_procs"), {
		"help": "number of stress procs to be run",
		"type": int,
		"default": 0,
	}),
	(("-n", "--num_stats"), {
		"help": "how many stat samples to collect in total (default infinite)",
		"type": int,
		"default": 0,
	}),
	(("-i", "--interval"), {
		"help": "target stat collection interval in seconds",
		"type": int,
		"default": 10,
	}),
	(("-P", "--report_path_format"), {
		"help": qa_common.escape_printf("report directory path format, %%s is targetIP_timestamp (optional)"),
		"default": os.path.join(my_path(), "reports", "%s"),
	}),
	(("-o", "--outfile"), {
		"help": "output file for report",
		"default": "report.jsonl.zlib",
	}),
	(("-r", "--rss_threshold"), {
		"help": "minimum RSS (ie. actual RAM usage) size for process to be logged",
		"type": int,
		"default": 4,
	}),
	(("-l", "--log_to_stdout"), {
		"help": "write the run log to stdout instead of a log file in report path",
		"action": "store_true",
	}),
]

class BackupZlibCompressor():
	def __init__(self, backup_fname):
		self.backup_fname = backup_fname
		self.comp = zlib.compressobj()
		self.content = b""

	def add_data(self, data):
		self.content += self.comp.compress(data)
		sacrificial_comp = self.comp.copy()
		outgoing_data = self.content + sacrificial_comp.flush()

		with qa_common.AtomicRewriteFile(self.backup_fname, "wb") as fd:
			os.write(fd, outgoing_data)

		return outgoing_data

def exec_stress(create_client, num_procs):
	clients = []
	if (num_procs > 0):
		qa_common.log("Creating %i stress processes" % num_procs)

	for _ in range(num_procs):
		client = create_client()
		client.exec_command(stress_script)
		clients.append(client)
	return clients

def kill_clients(clients):
	if (clients):
		qa_common.log("Killing %i stress processes" % len(clients))
	for client in clients:
		client.close()

# Also accept formats without %s specifier if user wants no timestamp
def try_format(string, args):
	try:
		result = string % args
	except TypeError:
		result = string
	return result

def generate_outfile_names(target_ip, report_path_format, outfile, log_to_stdout):
	test_name = qa_common.generate_test_name(target_ip)
	report_path = try_format(report_path_format, test_name)

	if(log_to_stdout):
		log_target = None
	else:
		log_target = os.path.join(report_path, logfile)

	report_file = os.path.join(report_path, outfile)
	return (report_file, log_target, report_path, test_name)

def setup_sigterm_handler():
	import signal

	def sigterm_handler(_signo, _stack_frame):
		qa_common.log("execute_test caught SIGTERM, exiting")
		raise SystemExit

	signal.signal(signal.SIGTERM, sigterm_handler)

def detach_from_stdin():
	si = open(os.devnull, "rb")
	os.dup2(si.fileno(), sys.stdin.fileno())

def main(argv):
	args = qa_common.parse_args(argv, cmdline_args)
	setup_sigterm_handler()
	detach_from_stdin()
	report = None

	# Apparently you cannot reconnect a failed client object, so let
	# reporter create its own clients whenever old one breaks down
	create_client = lambda: qa_common.create_ssh_client(args.target_ip,
	                                                    args.username,
	                                                    args.password)
	ofnames = generate_outfile_names(args.target_ip,
	                                 args.report_path_format,
	                                 args.outfile,
	                                 args.log_to_stdout)

	report_file, qa_common.log_target, report_path, test_name = ofnames
	os.makedirs(report_path, exist_ok=True)
	try:
		stress_clients = exec_stress(create_client,
		                             args.stress_procs)

		qa_common.log("Switching to reporter, writing report to %s" % 
		              report_file)

		try:
			my_reporter = reporter.Reporter(args.interval,
			                                create_client,
			                                args.num_stats,
			                                args.rss_threshold)

		except reporter.Reporter.NoConnectionError:
			qa_common.error("No connection to %s" % args.target_ip)
			return 1

		comp = BackupZlibCompressor(report_file)
		for measurement in my_reporter.mainloop():
			bdata = json.dumps(measurement).encode("utf-8") + b"\n"
			report = comp.add_data(bdata)

	# Exit gracefully without puking up a stack trace
	except (KeyboardInterrupt, SystemExit):
		pass

	finally:
		kill_clients(stress_clients)
		if (report is not None):
			qa_common.log("Exporting from %s to path %s" %
			              (report_file, report_path))

			exporter.export(report, report_path)

	return 0

# Do not list PID in case we're running as a module for some reason, because
# that would kill the parent instead. Thus it's best to do it here.
if (__name__ == "__main__"):
	with qa_common.PIDRegisterer(qa_common.PLOTFASTER_PID_FILE_DIR,
	                             qa_common.PLOTFASTER_PID_FILE_NAME,
	                             os.getpid()):
		sys.exit(main(sys.argv))

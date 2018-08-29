# Common functions for qa-tools

import os
import sys
import json
import zlib
import argparse
import contextlib
import time
import fcntl
import signal
import struct
import tempfile
import paramiko

TIMESTAMP_FORMAT = "%y%m%d_%H%M%S"

PLOTFASTER_PID_FILE_DIR = "/tmp/plotfaster/"
PLOTFASTER_PID_FILE_NAME = "pids"

# This needs to be set separately by every user of this module, sadly.
log_target = None

# Apparently posix does not allow preemptive file locking, but cooperative is
# possible with fcntl. This will lock a file from other threads using the same
# type of lock on the same file (multiple concurrent read locks allowed, but
# write locks are exclusive).
# Usage examples:
#
# with open("foo", "r") as f:
#     with FileLocker(f):
#         read_from_file(f)
#
# with open("foo", "w") as f:
#     with FileLocker(f, write=True):
#         write_to_file(f)
class FileLocker():
	def __init__(self, f, write = False):
		self.f = f
		if (write):
			self.lock_type = fcntl.F_WRLCK
		else:
			self.lock_type = fcntl.F_RDLCK

	def __enter__(self):
		self._lock(self.lock_type)

	def __exit__(self, *args):
		self._lock(fcntl.F_UNLCK)

	def _lock(self, lock_type):
		lock_data = struct.pack("hhllhh", lock_type, 0, 0, 0, 0, 0)
		fcntl.fcntl(self.f, fcntl.F_SETLKW, lock_data)

class PIDRegisterer():
	def __init__(self, pid_file_dir, pid_file_name, pid):
		self.pid_file_dir	= pid_file_dir
		self.pid_file_name	= pid_file_name
		self.pid		= pid

	def __enter__(self):
		os.makedirs(self.pid_file_dir, exist_ok=True)

		fpath = self.pidfile_path()
		self.create_file_if_inexistent(fpath)

		with open(fpath, "r+b") as f:
			with FileLocker(f, write=True):
				self.__add_pid(f, self.pid)

	def __exit__(self, *args):
		fpath = self.pidfile_path()
		if (os.path.exists(fpath)):
			with open(fpath, "r+b") as f:
				with FileLocker(f, write=True):
					self.__remove_pid(f, self.pid)

	# These functions should never be called unless f is a file locked for
	# writing and opened in "r+b" mode
	def __add_pid(self, f, pid):
		pid_list = self.read_pids_from_file(f)
		if (not pid in pid_list):
			pid_list.append(pid)

		self.write_pids_to_file(f, pid_list)

	def __remove_pid(self, f, pid):
		pid_list = self.read_pids_from_file(f)
		if (pid in pid_list):
			pid_list.remove(pid)

		self.write_pids_to_file(f, pid_list)

	def create_file_if_inexistent(self, fpath):
		try:
			os.mknod(fpath)
		except FileExistsError:
			pass

	def pidfile_path(self):
		return os.path.join(self.pid_file_dir, self.pid_file_name)

	@staticmethod
	def read_pids_from_file(f):
		result = []
		for line in f:
			try:
				pid = int(line.decode("utf-8"))
				result.append(pid)
			except ValueError:
				continue
		return result

	@staticmethod
	def write_pids_to_file(f, pid_list):
		f.seek(0)
		f.truncate()
		for p in pid_list:
			f.write(b'%i\n' % p)

class DelayedSignals():
	def __init__(self, *signos):
		self.signos = signos
		self.old_handlers = {}
		self.caught_signals = {}

	def __enter__(self):
		for signo in self.signos:
			old = signal.signal(signo, self.handler)
			self.old_handlers[signo] = old
			self.caught_signals[signo] = []

	def __exit__(self, *_):
		for signo in self.signos:
			old = self.old_handlers[signo]
			signal.signal(signo, old)

			for sig in self.caught_signals[signo]:
				old(*sig)

	def handler(self, signo, frame):
		self.caught_signals[signo].append((signo, frame))

class AtomicRewriteFile():
	def __init__(self, fname, mode = "wb"):
		self.fname = fname
		self.mode = mode

	def __enter__(self):
		dirname = os.path.dirname(os.path.abspath(self.fname))
		self.fd, self.tmp = tempfile.mkstemp(dir=dirname)
		return self.fd

	def __exit__(self, *args):
		exc_happened = not all(map(lambda arg: arg is None, args))

		# There is a chance that an interrupt would hit during the
		# rewrite, especially fsync() if the file is large. Hitting a
		# SIGINT or SIGTERM at that time during that time would leave
		# the temporary file remaining, so only handle the signals
		# after the write is complete to ensure removal.
		with DelayedSignals(signal.SIGINT, signal.SIGTERM):
			self.__do_rewrite(exc_happened)

		return not exc_happened

	# If an exception has happened (ie. some of the args are not None,
	# which is the sign for that), remove the temporary file instead of
	# copying it, to avoid data corruption
	def __do_rewrite(self, exc_happened):
		if (exc_happened):
			os.close(self.fd)
			os.remove(self.tmp)
		else:
			os.fsync(self.fd)
			os.close(self.fd)
			os.replace(self.tmp, self.fname)

class ZlibBufferedReader():
	DEFAULT_BS = 65536

	def __init__(self, deflated_buf):
		self.deflated_buf = deflated_buf
		self.inflated_buf = b""
		self.__decomp = zlib.decompressobj()
		self.eof = False

	def __enqueue_data(self, bs):
		block = self.__decomp.decompress(self.deflated_buf, bs)
		self.deflated_buf = self.__decomp.unconsumed_tail
		self.inflated_buf += block
		return len(block)

	def __dequeue_data(self, bs):
		block = self.inflated_buf[:bs]
		self.inflated_buf = self.inflated_buf[bs:]
		if (not self.inflated_buf and not self.deflated_buf):
			self.eof = True

		return block

	def read(self, bs):
		data = self.__dequeue_data(bs)
		bs_diff = bs - len(data)
		if (bs_diff > 0):
			enqsz = max(bs_diff, self.DEFAULT_BS)
			bs_queued = self.__enqueue_data(enqsz)

			deqsz = min(bs_queued, bs_diff)
			data += self.__dequeue_data(deqsz)

		return data

	def read_until_delim(self, delim):
		delim_loc = self.inflated_buf.find(delim)
		while (delim_loc < 0):

			# Did we run out of data to stream?
			if (self.__enqueue_data(self.DEFAULT_BS) == 0):
				delim_loc = len(self.inflated_buf)
				break

			delim_loc = self.inflated_buf.find(delim)

		return self.__dequeue_data(delim_loc + 1)

class Zlib2JSONIter():
	def __init__(self, report_zlib):
		self.reader = ZlibBufferedReader(report_zlib)

	def __iter__(self):
		return self

	def __next__(self):
		if (self.reader.eof):
			raise StopIteration

		line = self.reader.read_until_delim(b"\n").decode("utf-8")
		return json.loads(line)

def error(msg):
	log("Error: " + msg)

def warn(msg):
	log("Warning: " + msg)

# For help texts that contain printf format specifiers, escape the specifiers
# themselves because ArgumentParser itself uses printf-style substitution to
# generate help text
def escape_printf(string):
	result = ""
	for c in string:
		result += c
		if(c == "%"):
			result += c
	return result

def read_file(file_name):
	with open(file_name, "r") as f:
		file_buf = f.read()
	return file_buf

def write_file(file_name, data):
	with open(file_name, "w") as f:
		f.write(data)

def delete_file(file_name):
	os.remove(file_name)

def test_connection(create_client):
	dummy_cmd = "echo"
	try:
		with create_client() as client:
			remote_cmd(client, dummy_cmd)
			return True

	except (paramiko.SSHException,
	        paramiko.ssh_exception.NoValidConnectionsError):
		return False

# Print stderr, except for lines beginning with "Warning" to get rid of
# SSH key warnings that this command will invariably generate
def _remote_cmd_print_stderr(errstr):
	if(errstr != None):
		for line in errstr.strip().splitlines():
			if(not line.startswith("Warning")):
				log(line)

# Waits for process to terminate and returns its stdout
def remote_cmd(client, cmd, timeout = 1):
	si = so = se = None
	try:
		si, so, se = client.exec_command(cmd, timeout=timeout)
		stdout = so.read()
		stderr = se.read()

		_remote_cmd_print_stderr(stderr.decode("utf-8"))
		return stdout.decode("utf-8")
	finally:
		if (si is not None):
			si.close()
		if (so is not None):
			so.close()
		if (se is not None):
			se.close()

# Prints msg to a separate log instead of stdout. Multiline messages have the
# timestamp added to every line
def log(msg, newline = True):

	# Target write to stdout if log file is not defined (ie. "", None, etc)
	@contextlib.contextmanager
	def log_open(fname):
		try:
			if(fname):
				fh = open(fname, "a")
			else:
				fh = sys.stdout
			yield fh
		finally:
			if(fh != sys.stdout):
				fh.close()

	timestamp = make_timestamp()
	with log_open(log_target) as f:
		for line in str(msg).splitlines():
			f.write(timestamp + ": " + line + "\n")

def get_process_start_time(pid):
	return int(os.stat("/proc/%i" % int(pid)).st_atime)

def make_timestamp(seconds = None):
	return time.strftime(TIMESTAMP_FORMAT,
	                     time.localtime(seconds))

def generate_test_name(target_ip, pid = os.getpid()):
	return target_ip + "_" + make_timestamp(get_process_start_time(pid))

def jsonl_zlib_to_json(report_zlib, beginl = None, endl = None):
	errors = ((lambda beginl, endl: beginl < 0,
	          IndexError("first line number negative")),

	          (lambda beginl, endl: beginl > endl,
	          IndexError("first line number exceeds last")))

	result = []
	if (beginl == None):
		beginl = 0
	if (endl == None):
		endl = float("inf")

	for errcond, exc in errors:
		if (errcond(beginl, endl)):
			raise exc

	for i, measurement in enumerate(Zlib2JSONIter(report_zlib)):
		if (i >= beginl and i < endl + 1):
			result.append(measurement)

	return result

def json_to_jsonl_zlib(report):
	comp = zlib.compressobj()
	result = b""
	for measurement in report:
		bdata = json.dumps(measurement).encode("utf-8") + b"\n"
		result += comp.compress(bdata)

	result += comp.flush()
	return result

def parse_args(argv, cmdline_args):
	parser = argparse.ArgumentParser(prog=argv[0],
	                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)

	for arg_name, arg_params in cmdline_args:
		parser.add_argument(*arg_name, **arg_params)

	return parser.parse_args(argv[1:])

def create_ssh_client(hostname, username, password, port = 22):

	class IgnorePolicy(paramiko.MissingHostKeyPolicy):
		def missing_host_key(self, *_):
			pass

	client = paramiko.SSHClient()
	client.load_system_host_keys()
	client.set_missing_host_key_policy(IgnorePolicy)

	client.connect(hostname,
	               port=port,
	               username=username,
	               password=password)

	return client

#!/usr/bin/env python3

'''
* \file
* \brief reporter.py Remote performance logger
* 
* Copyright of Link Motion Ltd. All rights reserved. 
* 
* Contact: info@link-motion.com 
* 
* \author Pauli Oikkonen <pauli.oikkonen@link-motion.com> 
* 
* any other legal text to be defined later 
'''

import re
import os
import sys
import time
import paramiko

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "..", "common"))
import qa_common

short_delay = 0.1	# How much to wait per timing loop iteration
failed_connection_cooldown = 10

# If a name ends with _r, it means remote
cpu_freq_path_r = " /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
uptime_path_r = "/proc/uptime"
load_path_r = "/proc/loadavg"
mem_path_r = "/proc/meminfo"

class Reporter():
	class NoConnectionError(Exception):
		pass

	class CPUUsageReader():
		def __init__(self):
			self.first_run = True
			self.old_run_time = []
			self.old_idle_time = []

		def read(self, client):
			my_cmd = "cat /proc/stat"

			# Substrings are 1) cpu name, and time spent in 2) user mode,
			# 3) low priority user mode, 4) system mode, 5) idle
			pattern = "^(cpu[0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+)"
			p = re.compile(pattern)

			output = qa_common.remote_cmd(client, my_cmd).splitlines()
			i = 0
			result = []
			for line in output:
				match = p.match(line)
				if(not match): continue

				data = match.group(0, 1, 2, 3, 4, 5)
				run_time = float(data[2]) + float(data[3]) + \
				           float(data[4])

				idle_time = float(data[5])

				if(self.first_run):
					self.old_run_time.append(run_time)
					self.old_idle_time.append(idle_time)
					result.append(0.0)

				else:
					old_run_time = self.old_run_time[i]
					old_idle_time = self.old_idle_time[i]

					run_time_diff = run_time - old_run_time
					idle_time_diff = idle_time - old_idle_time
					usage = run_time_diff / (run_time_diff + \
						idle_time_diff)

					result.append(round(usage, 3))
					self.old_run_time[i] = run_time
					self.old_idle_time[i] = idle_time

				i += 1

			self.first_run = False
			return result

	# rss_threshold: How large a process' Resident Set Size (ie. RAM usage)
	# needs to be to get the process logged.
	def __init__(self, interval, create_client, num_stats, rss_threshold):
		self.interval = interval
		self.create_client = create_client
		self.num_stats = num_stats
		self.inf_stats = num_stats == 0
		self.rss_threshold = rss_threshold

		if (not qa_common.test_connection(create_client)):
			raise self.NoConnectionError()

		with create_client() as client:
			self.device_clk_tck = int(self.getconf(client, "CLK_TCK"))

		# Will not get CPU usage because this is the first run time, but we can
		# get the number of CPU cores this way
		self.cpu_usage_reader = self.CPUUsageReader()

	def getconf(self, client, var):
		return qa_common.remote_cmd(client, "getconf %s" % var)

	# Attempt to do a single measurement by calling measure_func and, if it
	# succeeds, storing its result to measurement. In case of a connection
	# failure by measure_func, does not modify curr_measurement, but will
	# also silence the exception so that a failed measurement would not
	# bring down the entire test.
	@staticmethod
	def try_measure(measurement, key, measure_func):
		try:
			measurement[key] = measure_func()
			return True
		except paramiko.SSHException as e:
			qa_common.warn("Failed to sample %s: %s" % (key, e))
			return False

	def do_measurement(self, client):
		what_to_measure = (
			# Read CPU frequency first since it changes very easily
			("cpu_freq",	lambda: self.get_cpu_freq(client)),
			("mem_stats",	lambda: self.get_memory_stats(client)),
			("uptime",	lambda: self.get_uptime(client)),
			("procs",	lambda: self.get_procs(client)),
			("load",	lambda: self.get_load(client, 0)),
			("cpu_usage",	lambda: self.cpu_usage_reader.read(client)),
		)
		measurement = {}
		for name, func in what_to_measure:
			self.try_measure(measurement, name, func)

		return measurement

	# Works as a generator, yields generated data back to caller. Runs as
	# long as the client is good
	def __measurement_loop(self, client, start_time):
		last_stat = start_time
		qa_common.log("Starting to record data")

		while(True):
			measurement = {}
			next_stat = last_stat + self.interval
			if(time.time() > next_stat):
				qa_common.warn("Gathering data took longer than the stat interval")

			measurement = self.do_measurement(client)
			if (measurement):
				rt = round(time.time() - start_time, 2)
				measurement["runtime"] = rt
				yield measurement
			else:
				qa_common.warn("Measurement failed!")
				return

			while(time.time() < next_stat):
				time.sleep(short_delay)

			last_stat = next_stat

	# Needed to ensure that we always have a live client in the actual
	# measurement loop (__measurement_loop) that always gets properly
	# closed when it dies (ie. we want to have the actual measurement loop
	# happen inside a with() block where the client is created).
	def mainloop(self):
		if (self.inf_stats):
			s_nstats = "infinite"
		else:
			s_nstats = str(self.num_stats)

		qa_common.log("Collecting %s stats on %i second intervals" %
		              (s_nstats, self.interval))

		i = 0
		start_time = time.time()
		while True:
			qa_common.log("Trying to create an SSH client")
			try:
				with self.create_client() as client:
					for m in self.__measurement_loop(client, start_time):
						yield m

						if(not self.inf_stats):
							i += 1
							if(i == self.num_stats):
								return

			except paramiko.ssh_exception.NoValidConnectionsError:
				qa_common.error("No connection!")
				time.sleep(failed_connection_cooldown)

	def get_cpu_freq(self, client):
		my_cmd = "cat %s" % cpu_freq_path_r
		output = qa_common.remote_cmd(client, my_cmd)
		return int(output.strip())

	# Load average. Which can be 0, 1 or 2, corresponding to average over 1, 5 or 15
	# minutes
	def get_load(self, client, which):
		assert(which >= 0 and which <= 2)
		my_cmd = "cat %s" % load_path_r
		output = qa_common.remote_cmd(client, my_cmd)
		return float(output.split()[which])

	# Assumes that /proc/uptime output is simply [uptime_in_s] [idletime_in_s]
	def get_uptime(self, client):
		my_cmd = "cat %s" % uptime_path_r
		output = qa_common.remote_cmd(client, my_cmd)
		return float(output.split()[0])

	def get_memory_stats(self, client):

		def parse_meminfo(data):
			result = {}
			for line in data.splitlines():
				line = line.strip()
				if (line == ""):
					continue

				atoms = line.split()
				key = atoms[0].rstrip(":")
				value = int(atoms[1])
				if (len(atoms) > 2):
					unit = atoms[2]
				else:
					unit = "B"

				result[key] = self.parse_unit(value, unit)
			return result

		result = {}
		my_cmd = "cat %s" % mem_path_r
		mem_output = qa_common.remote_cmd(client, my_cmd)
		mem_stats = parse_meminfo(mem_output)

		result["total"] = mem_stats["MemTotal"]
		result["free"] = mem_stats["MemFree"] + mem_stats["SwapFree"]
		result["buffers"] = mem_stats["Buffers"]
		result["cache"] = mem_stats["Cached"] + mem_stats["Slab"]
		result["used"] = result["total"] - \
		                 result["free"] - \
		                 result["buffers"] - \
		                 result["cache"]
		return result

	# page_size is the size of a virtual memory page in kB's since that's
	# what /proc/<pid>/stat gives for RSS
	def parse_procs(self, line, page_size):
		try:
			# Tricky regex, but basically splits by any whitespace
			# that is not enclosed in parentheses
			stat_str = line.strip()
			stats = re.split(r"\s+(?![^()]*\))", stat_str)

			pid =		int(stats[0])
			proc_name =	stats[1].strip("()")
			utime =		int(stats[13]) / self.device_clk_tck
			stime =		int(stats[14]) / self.device_clk_tck
			rss =		int(stats[23]) * page_size

			proc_name_with_pid = "%s_%i" % (proc_name, pid)

			return {"proc_name":	proc_name_with_pid,
			        "utime":	utime,
			        "stime":	stime,
			        "rss":		rss}

		except IndexError:
			return None

	def get_procs(self, client):
		result = []
		page_size = int(self.getconf(client, "PAGE_SIZE")) / 1024

		vm_cmd = "cat /proc/[1-9]*/stat"
		stdout = qa_common.remote_cmd(client, vm_cmd)
		for line in stdout.splitlines():
			proc = self.parse_procs(line, page_size)
			if (proc["rss"] >= self.rss_threshold):
				result.append(proc)

		return result

	@staticmethod
	def parse_unit(value, unit):
		multiplier = {
			"MB":	1024,
			"GB":	1024 * 1024,
			"B":	1 / 1024,
			"kB":	1
		}[unit]

		return value * multiplier

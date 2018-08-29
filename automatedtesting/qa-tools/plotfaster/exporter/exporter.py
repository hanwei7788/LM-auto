#!/usr/bin/env python3

'''
* \file
* \brief exporter.py CSV to bitmap graph exporting tool
* 
* Copyright of Link Motion Ltd. All rights reserved. 
* 
* Contact: info@link-motion.com 
* 
* \author Pauli Oikkonen <pauli.oikkonen@link-motion.com> 
* 
* any other legal text to be defined later 
'''

import itertools
import json
import os
import re
import sys
import matplotlib.pyplot as pyplot

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "..", "common"))
import qa_common

DEFAULT_CONF_FILE = os.path.join(my_path(), "config.json")
REBOOT_COLOR = (0.2, 0.2, 0.2)

class UnitConvThreshold():
	def __init__(self, divisor, threshold_units, name):
		self.divisor = divisor
		self.threshold = threshold_units * divisor
		self.name = name

# Values are the size of the unit in seconds, uptime threshold in units for
# division, and the name of the unit. Note that these need to be arranged from
# the largest to the smallest
THRESHOLD_SET = {
	"time" : [
		UnitConvThreshold(60 * 60 * 24, 3, "days"),
		UnitConvThreshold(60 * 60, 10, "hours"),
		UnitConvThreshold(60, 10, "minutes"),
		UnitConvThreshold(1, 0, "seconds"),
	],
	"size" : [
		UnitConvThreshold(1024 * 1024, 2, "GB"),
		UnitConvThreshold(1024, 2, "MB"),
		UnitConvThreshold(1, 0, "kB"),
	],
	"temp" : [
		UnitConvThreshold(1000, 1, "deg C"),
		UnitConvThreshold(1, 0, "(unknown)"),
	],
	"freq" : [
		UnitConvThreshold(1000 * 1000, 1, "GHz"),
		UnitConvThreshold(1000, 1, "MHz"),
		UnitConvThreshold(1, 0, "(unknown)"),
	],
	"percent" : [
		UnitConvThreshold(0.01, 0, "%"),
	],
	"none" : [
		UnitConvThreshold(1, 0, "(unknown)"),
	],
}

cmdline_args = [
	(("infile",), {
		"metavar": "INFILE",
		"help": "input report file",
	}),
	(("-c", "--conffile"), {
		"help": "config file (default: %s)" % DEFAULT_CONF_FILE,
		"default": DEFAULT_CONF_FILE,
	}),
	(("-g", "--graph_path"), {
		"help": "directory where graphs are written (created if nonexistent)",
		"default": os.environ["PWD"],
	}),
]

class InternalError(Exception):
	pass

def converted_unit(graph_units, max_value):
	if graph_units in THRESHOLD_SET:
		thresholds = THRESHOLD_SET[graph_units]
	else:
		thresholds = THRESHOLD_SET["none"]

	for threshold in thresholds:
		if(float(max_value) >= threshold.threshold):
			return (threshold.divisor, threshold.name)

	raise InternalError("No suitable threshold found for " + graph_units)

def find_labels(data):
	CUSTOMLABEL_NAME = "customlabel"
	labels = []

	for measurement in qa_common.Zlib2JSONIter(data):
		if (CUSTOMLABEL_NAME in measurement.keys()):
			label_name = measurement[CUSTOMLABEL_NAME]
			label_runtime = measurement["runtime"]
			labels.append((label_name, label_runtime))
	return labels

def gen_graph(data, name, content):
	result = []
	for measurement in qa_common.Zlib2JSONIter(data):
		current_stat = measurement[name]
		runtime = measurement["runtime"]

		if (content == None):
			subresult = current_stat
		else:
			subresult = {substat: current_stat[substat] for substat in content}

		result.append((runtime, subresult))
	return result

def gen_graphs(data, conf):
	graphs = {}
	for name, content in conf["regular_graphs"].items():
		graph = gen_graph(data, name, content)
		graphs[name] = graph

	return graphs

def proc_by_name(procs, wanted_proc_name):
	for proc in procs:
		# Process names will have the PID appended, so a regex has to
		# be used here
		proc_pattern = "^%s_[1-9][0-9]*$" % wanted_proc_name
		if (re.search(proc_pattern, proc["proc_name"]) != None):
			return proc

	raise KeyError(wanted_proc_name)

def get_procs_instant(measurement, wanted_procs, stat):
	procs = measurement["procs"]
	result = {}

	for proc_name in wanted_procs:
		try:
			proc_status = proc_by_name(procs, proc_name)
			proc_name_pid = proc_status["proc_name"]
		except KeyError:
			continue

		proc_stat = proc_status[stat]
		result[proc_name_pid] = proc_stat

	return result

def gen_proc_graphs(data, conf):
	wanted_procs = conf["procs"]

	# Lists will contain tuples of runtime and a dict mapping then-active
	# process names to their values in question

	# result["rss"] = [(0.1, {"init": 1000, "ui_center": 350000}),
	#                  (9.9, {"init": 1001, "ui_center": 380000})]
	result = {
		"utime":	[],
		"stime":	[],
		"rss":		[],
	}
	for measurement in qa_common.Zlib2JSONIter(data):
		runtime = measurement["runtime"]

		for current_value, stat_procs in result.items():
			proc_values = get_procs_instant(measurement,
			                                wanted_procs,
			                                current_value)

			stat_procs.append((runtime, proc_values))
	return result

def extract_graph_dicts(graph):
	result = {}
	for runtime, measurement in graph:
		for proc, stat in measurement.items():

			if (proc not in result):
				result[proc] = []

			result[proc].append((runtime, stat))
	return result

def extract_graph_lists(graph, key_name_format = "%i"):
	result = {}
	for runtime, measurement in graph:
		for i, stat in enumerate(measurement):

			stat_name = key_name_format % i
			if (stat_name not in result):
				result[stat_name] = []

			result[stat_name].append((runtime, stat))
	return result

def gen_plot_size(w, h, dpi = 100):
	w_in = w / dpi
	h_in = h / dpi
	return {"figsize": (w_in, h_in), "dpi": dpi}

def find_max_time_value(curve, old_max_time_value):
	found_time, found_value = old_max_time_value
	for time, value in curve:
		if (value > found_value):
			found_value = value
		if (time > found_time):
			found_time = time

	return (found_time, found_value)

def scale_curve(curve, value_divisor, time_divisor):
	for i, measurement in enumerate(curve):
		time, value = measurement
		time /= time_divisor
		value /= value_divisor
		curve[i] = (time, value)

def plot_graph(graph_name, graph_curves, fname, w, h, graph_units, customlabels):
	fig = pyplot.figure(**gen_plot_size(w, h))
	ax = fig.add_subplot(111)
	ax.set(title=graph_name)
	ax.grid()

	# Find the maximum for the graph's dataset first for scaling of all
	# the data, because matplotlib itself offers no good way of scaling
	# data already given to the plot
	max_time_value = (0, 0)
	for _, curve in graph_curves.items():
		max_time_value = find_max_time_value(curve, max_time_value)

	max_time, max_value = max_time_value
	divisor, unit = converted_unit(graph_units, max_value)
	runtime_divisor, runtime_unit = converted_unit("time", max_time)
	ax.set(ylabel=unit, xlabel=runtime_unit)

	for curve_name in sorted(graph_curves.keys()):
		curve = graph_curves[curve_name]
		scale_curve(curve, divisor, runtime_divisor)
		ax.plot(*zip(*curve), label=curve_name)

	for label_name, x in customlabels:
		x /= runtime_divisor
		ax.axvline(x=x, color=REBOOT_COLOR, dashes=[2, 2])
		ax.text(x, (max_value / divisor) / 2,
		        label_name,
		        rotation="vertical",
		        ha="right")

	ax.set_xlim(xmin=0, xmax=None)
	ax.set_ylim(ymin=0, ymax=None)

	legend = ax.legend(*ax.get_legend_handles_labels(),
	                   loc="center left",
	                   bbox_to_anchor=(1, 0.5))

	fig.savefig(fname, bbox_extra_artists=(legend,), bbox_inches="tight")

def get_graph_data_type(graph_data):
	_, measurement = graph_data[0]
	return type(measurement)

def convert_graph(graph_data, graph_name):
	graph_data_type = get_graph_data_type(graph_data)

	if (graph_data_type == dict):
		return extract_graph_dicts(graph_data)
	elif (graph_data_type == list):
		return extract_graph_lists(graph_data)
	elif (graph_data_type == float or graph_data_type == int):
		return {graph_name: graph_data}
	else:
		raise InternalError("Unsupported data type " + \
		                    repr(graph_data_type) + \
		                    " for graph " + graph_name)

# This function ought to be called when used as a module, main() is for command
# line usage
def export(report_zlib, graph_path, config_file = os.path.join(DEFAULT_CONF_FILE)):
	with open(config_file, "r") as f:
		conf = json.load(f)

	graphs = gen_graphs(report_zlib, conf)
	proc_graphs = gen_proc_graphs(report_zlib, conf)
	customlabels = find_labels(report_zlib)

	graph_w = conf["settings"]["graph_w"]
	graph_h = conf["settings"]["graph_h"]

	for graph_name, graph_data in itertools.chain(proc_graphs.items(),
	                                              graphs.items()):

		fname = os.path.join(graph_path, graph_name + ".png")
		graph_curves = convert_graph(graph_data, graph_name)

		graph_units = conf["units"].get(graph_name, None)
		graph_name = conf["aliases"].get(graph_name, graph_name)

		plot_graph(graph_name,
		           graph_curves,
		           fname,
		           graph_w,
		           graph_h,
		           graph_units,
		           customlabels)

def main(argv):
	args = qa_common.parse_args(argv, cmdline_args)
	try:
		with open(args.infile, "rb") as f:
			report_zlib = f.read()
	except FileNotFoundError as e:
		qa_common.error(e)

	os.makedirs(args.graph_path, exist_ok=True)
	export(report_zlib, args.graph_path, args.conffile)

if (__name__ == "__main__"):
	sys.exit(main(sys.argv))

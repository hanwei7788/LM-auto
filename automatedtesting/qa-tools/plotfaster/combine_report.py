#!/usr/bin/env python3

import enum
import json
import zlib
import sys
import os

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "common"))
import qa_common

# SAME_RUN can be used when combining two reports from a device that has been
# up between the reports (such as in case of a temporary network failure),
# DIFFERENT_BOOTS can be used otherwise eg. to display multiple runs on same
# graph.
class CombineModes(enum.Enum):
	SAME_RUN = 1
	DIFFERENT_BOOTS = 2

# A list of tuples instead of a dict to preserve order, for obvious reasons
cmdline_args = [
	(("old",), {
		"metavar":	"OLD",
		"help":		"report from the old run"
	}),
	(("new",), {
		"metavar":	"NEW",
		"help":		"report from the new run"
	}),
	(("target",), {
		"metavar":	"TARGET",
		"help":		"target file to write into"
	}),
	(("--combine-boots", "-c"), {
		"dest":		"combine_mode",
		"action":	"store_const",
		"default":	CombineModes.SAME_RUN,
		"const":	CombineModes.DIFFERENT_BOOTS,
		"help":		"combine two different boots instead of two captures from one boot"
	}),
]

def get_extreme_datum(data, name, comp):
	found = None
	for measurement in qa_common.Zlib2JSONIter(data):
		if (name not in measurement):
			continue

		candidate = measurement[name]
		if (found == None):
			found = candidate
		else:
			found = comp(found, candidate)
	return found

def move_compressed_data(data_reader, compressor):
	result = b""
	while not data_reader.eof:
		block = data_reader.read(data_reader.DEFAULT_BS)
		result += compressor.compress(block)

	return result

def sequentialize_by_uptime(old_data, new_data):
	old_uptime_min = get_extreme_datum(old_data, "uptime", min)
	new_uptime_min = get_extreme_datum(new_data, "uptime", min)
	delta = new_uptime_min - old_uptime_min

	comp = zlib.compressobj()
	old_reader = qa_common.ZlibBufferedReader(old_data)
	result = move_compressed_data(old_reader, comp)

	for measurement in qa_common.Zlib2JSONIter(new_data):
		measurement["runtime"] += delta
		measurement_data = json.dumps(measurement).encode("utf-8") + b"\n"
		result += comp.compress(measurement_data)

	return result + comp.flush()

def sequentialize_two_boots(old_data, new_data):
	old_runtime_max = get_extreme_datum(old_data, "runtime", max)
	new_runtime_min = get_extreme_datum(new_data, "runtime", min)
	delta = old_runtime_max - new_runtime_min

	comp = zlib.compressobj()
	old_reader = qa_common.ZlibBufferedReader(old_data)
	result = move_compressed_data(old_reader, comp)

	for i, measurement in enumerate(qa_common.Zlib2JSONIter(new_data)):
		measurement["runtime"] += delta
		if (i == 0):
			measurement["customlabel"] = "New boot"

		measurement_data = json.dumps(measurement).encode("utf-8") + b"\n"
		result += comp.compress(measurement_data)

	return result + comp.flush()

def combine(old_data, new_data, mode):
	if (mode == CombineModes.SAME_RUN):
		result = sequentialize_by_uptime(old_data, new_data)
	elif (mode == CombineModes.DIFFERENT_BOOTS):
		result = sequentialize_two_boots(old_data, new_data)
	return result

def main(argv):
	args = qa_common.parse_args(argv, cmdline_args)
	with open(args.old, "rb") as f:
		old_data = f.read()

	with open(args.new, "rb") as f:
		new_data = f.read()

	result = combine(old_data, new_data, args.combine_mode)
	with open(args.target, "wb") as f:
		f.write(result)

	return 0

if(__name__ == "__main__"):
	sys.exit(main(sys.argv))

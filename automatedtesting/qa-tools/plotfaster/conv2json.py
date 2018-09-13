#!/usr/bin/env python3

import json
import os
import sys
import zlib

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "common"))
import qa_common

cmdline_args = [
	(("-s", "--start"), {
		"default":	None,
		"type":		int,
		"help":		"index of first datum to include in created json report",
	}),
	(("-e", "--end"), {
		"default":	None,
		"type":		int,
		"help":		"index of last datum to include in created json report",
	}),
	(("-i", "--indent"), {
		"default":	None,
		"type":		int,
		"help":		"indentation for the created json",
	}),
	(("-r", "--sort_keys"), {
		"action":	"store_true",
		"help":		"sort the json keys",
	}),
	(("file",), {
		"metavar":	"FILE",
		"help":		"compressed jsonl report to convert into regular json",
	}),
]

def main(argv):
	args = qa_common.parse_args(argv, cmdline_args)
	try:
		with open(args.file, "rb") as f:
			data = f.read()

		report = qa_common.jsonl_zlib_to_json(data,
		                                      args.start,
		                                      args.end)

		print(json.dumps(report,
		                 sort_keys	= args.sort_keys,
		                 indent		= args.indent))
		return 0

	except zlib.error as e:
		print("Zlib error: %s" % e, file=sys.stderr)
		return 1

	except json.decoder.JSONDecodeError as e:
		print("JSON decode error: %s" % e, file=sys.stderr)
		return 1

	except IndexError as e:
		print("IndexError: %s" % e, file=sys.stderr)
		return 1

if (__name__ == "__main__"):
	sys.exit(main(sys.argv))

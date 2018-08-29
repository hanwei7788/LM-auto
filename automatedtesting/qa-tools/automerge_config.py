#!/usr/bin/env python3

import argparse
import json
import shutil
import sys

from common import qa_common

cmdline_args = [
	(("-s", "--template_suffix"), {
		"help": "suffix for the template file",
		"default": ".example",
	}),
	(("-b", "--backup_suffix"), {
		"help": "suffix for a backup of original config file",
	}),
	(("template_file",), {
		"metavar": "TEMPLATE_FILE",
		"help": "template file updated by git pull",
	}),
]

# Recursively copies every dict item that is found in template but not in conf,
# to conf. Can be used to merge newly added configuration items introduced in
# config file template via git, to each user's personal config file. Modifies
# conf.
def merge_new_template_fields(conf, template):
	for key, value in template.items():
		if (key not in conf):
			conf[key] = value
		else:
			if (isinstance(value, dict)):
				merge_new_template_fields(conf[key], value)

def read_json(fn, inexistence_ok=False):
	try:
		with open(fn) as f:
			return json.load(f)
	except FileNotFoundError as e:
		if (inexistence_ok):
			return dict()
		else:
			raise

def suffixless(string, suffix):
	if (not string.endswith(suffix)):
		raise LookupError("no suffix %s in %s" % (suffix, string))

	return string[:-len(suffix)]

def main(argv):
	args = qa_common.parse_args(argv, cmdline_args)
	template_fn = args.template_file
	suffix = args.template_suffix

	try:
		conf_fn = suffixless(template_fn, suffix)
		if (args.backup_suffix is not None):
			backup_fn = conf_fn + args.backup_suffix
			shutil.copyfile(conf_fn, backup_fn)

		conf = read_json(conf_fn, inexistence_ok=True)
		template = read_json(template_fn)

	except (LookupError,
	        FileNotFoundError,
	        json.decoder.JSONDecodeError) as e:
		print(e, file=sys.stderr)
		return 1

	merge_new_template_fields(conf, template)
	with open(conf_fn, "w") as f:
		json.dump(conf, f, indent=4, sort_keys=True)

if (__name__ == "__main__"):
	sys.exit(main(sys.argv))

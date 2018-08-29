#!/usr/bin/python2.7

from time import sleep, strftime
import argparse
import sys
import re
import subprocess
from os import path, makedirs

def my_path(): return path.dirname(path.realpath(sys.argv[0]))
sys.path.append(my_path() + "/../common")
import qa_common

# Default values
gdb_path = "/altdata/devel/bin/gdb"
partition_roots = ["/", "/usr/lib/lm_containers/ivi/rootfs/"]
core_dir = "/cores/"

target_ip = None
user = "root"
passwd = "skytree"

# How gdb will suggest a package to be installed
zypper_suggested_cmd = "Missing separate debuginfos, use: zypper install "

cred_file_path = "/etc/zypp/credentials.d/"
cred_file_name = "lm"
cred_file_local = my_path() + "/zypper_credentials.conf"

val_args = [ \
["-T", "--target_ip", "target SUT IP", str, True], \
["-u", "--username", "username for login", str, False], \
["-p", "--password", "password for login", str, False], \
["-g", "--gdb_path", "path for gdb (default %s)" % gdb_path, str, False], \
["-pr", "--partition_roots", "prefixes for core dump paths, ie. paths to different partitions' roots (without the \"cores/\", default \"%s\")" % " ".join(partition_roots), str, False], \
["-zp", "--zypper_pwdfile", "password file for zypper (default %s)" % cred_file_local, str, False], \
["-l", "--log_file", "name for a log file (leave empty for stdout)", str, False], \
]

bool_args = [ \
]

def parse_args():
	global target_ip, user, passwd, gdb_path, partition_roots, cred_file_local

	parser = argparse.ArgumentParser()
	for arg in val_args:
		parser.add_argument(arg[0], arg[1], help=qa_common.escape_printf(arg[2]),\
			type=arg[3], required=arg[4])
	for arg in bool_args:
		parser.add_argument(arg[0], arg[1], help=qa_common.escape_printf(arg[2]),\
		action="store_true")
	
	args = parser.parse_args()
	if(args.target_ip != None):
		target_ip = args.target_ip

	if(args.username != None):
		user = args.username

	if(args.password != None):
		passwd = args.password
	
	if(args.gdb_path != None):
		gdb_path = args.gdb_path
	
	if(args.partition_roots != None):
		partition_roots = args.partition_roots

	if(args.zypper_pwdfile != None):
		cred_file_local = args.zypper_pwdfile

	qa_common.log_file = args.log_file

def inject_credentials(cred_file_local, path, fname):
	mkdir_cmd = ["mkdir", "-p", path]
	cred_file = qa_common.read_file(cred_file_local)
	
	cred_file_name = path + fname
	inject_write_cmd = "echo \"" + cred_file + "\" > " + cred_file_name
	inject_cmd_template = "if [ ! -f \"%s\" ] ; then %s ; fi"
	inject_cmd = inject_cmd_template % (cred_file_name, inject_write_cmd)

	qa_common.remote_cmd(target_ip, user, passwd, mkdir_cmd)
	qa_common.remote_cmd(target_ip, user, passwd, inject_cmd)

# Returns a list whose atoms are dicts, with indexes binary and corefile
def get_coredumps(partition_roots, core_dir):

	def parse_dump_files(core_list, result_list, core_path_prefix):

		# Catch binary name from file output, we're not interested in
		# anything else
		pattern = ".*ELF.+core file.+from '([^ ]+).*'"
		re_prog = re.compile(pattern)
		binary_match_id = 1

		# Last atom is apparently always a blank line
		for dump in core_list:
			if(dump == ""):
				continue
	
			dump = dump.replace(" ", "\ ")

			file_cmd = ["file", dump]
			output = qa_common.remote_cmd(target_ip, user, passwd, file_cmd)
			re_match = re_prog.match(output)

			# Notify user if there is for example an empty file, but keep
			# going anyway
			if(re_match == None):
				qa_common.error("Non-matching core file " + dump)
				continue

			# If the dumps are on some other than current partition,
			# prefix the binary names with path to partition root
			binary = re_match.group(binary_match_id)
			binary = core_path_prefix + binary
			this_dump = {"binary" : binary,	"corefile" : dump}
			result_list.append(this_dump)

	if(not isinstance(partition_roots, list)):
		if(isinstance(partition_roots, str)):
			partition_roots = [partition_roots]
		else:
			partition_roots = []

	result_list = []

	# Note: [1, 2] + [3, 4, 5] = [1, 2, 3, 4, 5], not for example
	# [1, 2, [3, 4, 5]]
	assert(isinstance(core_dir, str));
	for core_path_prefix in partition_roots:
		assert(isinstance(core_path_prefix, str));
		core_path = core_path_prefix + core_dir
		get_corelist_cmd = ["find"] + [core_path] + ["-type", "f"]
		core_list = qa_common.remote_cmd(target_ip, \
		                                 user, \
		                                 passwd, \
		                                 get_corelist_cmd).split("\n")
		                                 
		parse_dump_files(core_list, result_list, core_path_prefix)

	return result_list

def invoke_gdb(gdb_path, binary, core_dump):

	# Use echo q instead of -ex q, even though it is very hacky. For some
	# reason, gdb will not give us the missing debuginfo information at all
	# if run with -ex q, so it needs to be worked around this way
	gdb_cmd = "echo q | %s %s %s 2>&1" % (gdb_path, binary, core_dump)
	result = qa_common.remote_cmd(target_ip, user, passwd, gdb_cmd, \
		get_stderr=True).split("\n")
	
	return result

# Assumes that gdb_output only contains stderr from gdb -ex q, split into a list
# of lines. Outputs a list of package names. If there is something unparseable
# in gdb_output, gives error message and continues reading from next line.
def get_package_list(gdb_output):
	all_pkg_names = []

	# The missing debuginfo format is:
	# "Missing separate debuginfos, use: zypper install a b c", where a, b
	# and c are the missing packages
	for line in gdb_output:
		if(line.startswith(zypper_suggested_cmd)):
			pkg_names = line[len(zypper_suggested_cmd):].split(" ")
			all_pkg_names.extend(pkg_names)
	return all_pkg_names

def install_packages(packages):
	qa_common.log("Installing %i debuginfo packages" % len(packages))
	qa_common.log("\n".join(packages))

	# Intended as immutable
	install_cmd_base = ["zypper", "--non-interactive", "--no-gpg-checks", "in", "-C"]
	successful = 0
	for package in packages:
		try:
			# Copy the cmd base to be amended instead of modifying
			# the original
			install_cmd = install_cmd_base + [package]
			qa_common.remote_cmd(target_ip, user, passwd, install_cmd,
				get_stderr=True)

			successful += 1

		except subprocess.CalledProcessError as e:
			qa_common.log("Error message from remote:\n%s\n" % e.output)

	qa_common.log("Successfully installed %i packages" % successful)

def get_all_packages(dumps):
	all_packages = []
	qa_common.log("Getting package lists for all core dumps...\n")

	for dump in dumps:
		binary = dump["binary"]
		corefile = dump["corefile"]

		qa_common.log(" " + corefile)
		gdb_output = invoke_gdb(gdb_path, binary, corefile)
		packages = get_package_list(gdb_output)
		all_packages.extend(packages)

	qa_common.log("\ndone.")
	return all_packages
	
def main():
	parse_args()
	if(not qa_common.test_connection(target_ip, user, passwd)):
		qa_common.error("Couldn't connect to %s" % target_ip)
		sys.exit(1)
	qa_common.log("Injecting credentials from file %s" % cred_file_local)
	inject_credentials(cred_file_local, cred_file_path, cred_file_name)

	dumps = get_coredumps(partition_roots, core_dir)
	packages = get_all_packages(dumps)
	if(len(packages) > 0):
		install_packages(packages)
	else:
		qa_common.log("No packages to be installed!")

main()

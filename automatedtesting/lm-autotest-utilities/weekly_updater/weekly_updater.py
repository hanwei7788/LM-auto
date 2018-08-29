#!/usr/bin/env python3

import time
import sys
import os

from device_type import Device
import check_run_update
import common

# If an update for some reason takes longer than update_cycle_period, prevent
# loop iterations from accumulating
def get_next_run(latest):
	assert(isinstance(latest, int))
	assert(isinstance(common.UPDATE_CYCLE_PERIOD, int))

	next_run = latest + common.UPDATE_CYCLE_PERIOD
	while next_run < common.now_ts():
		next_run += common.UPDATE_CYCLE_PERIOD
	return next_run

def update_loop(devices):
	next_run = common.now_ts()
	while True:
		try:
			config = common.read_config(common.CONFIG_FILE)
			update_device_list(devices, config)

			check_run_update.run_update_cycle(devices, config)
			next_run = get_next_run(next_run)
			while(common.now_ts() < next_run):
				time.sleep(common.LONG_SLEEP_DELAY)

		except common.SigTermCaught:
			common.log("Caught SIGTERM, exiting")
			return

# NOTE: Will modify devices
def update_device_list(devices, config):
	all_devices_in_config = []
	image_types = common.config_get_list(config, "general", "image_types")

	# Get all devices in config and add any newly found devices
	for image_type in image_types:
		device_names = common.config_get_list(config, image_type, "devices")
		for device_name in device_names:
			all_devices_in_config.append(device_name)
			add_if_inexistent(devices, device_name, image_type, config)

	# Remove any devices that were removed from config
	for device in devices:
		if(not device.name in all_devices_in_config):
			devices.remove(device)

def add_if_inexistent(devices, device_name, image_type, config):
	if(not any(device_name == existing.name for existing in devices)):
		device = new_device(device_name, image_type, config)
		if(device != None):
			devices.append(device)

def new_device(device_name, image_type, config):
	device_conf_fname = config.get(device_name, "config_file")
	if(device_conf_fname == ""):
		common.log("Warning: No config file for %s, cannot update" % device_name)
		return None

	device_conf = common.read_config(device_conf_fname)
	device_ip = config.get(device_name, "ip")

	device = Device(device_name, device_conf, device_conf_fname, device_ip, image_type)
	return device

def install_sigterm_handler():
	import signal

	def sigterm_handler(_signo, _stack_frame):
		raise common.SigTermCaught

	signal.signal(signal.SIGTERM, sigterm_handler)

def detach_stdin():
	si = open(os.devnull, "rb")
	os.dup2(si.fileno(), sys.stdin.fileno())

def check_conf_file():
	if (not os.path.isfile(common.CONFIG_FILE)):
		shutil.copyfile(common.CONFIG_FILE_TEMPLATE,
		                common.CONFIG_FILE)

def main():
	check_conf_file()
	detach_stdin()
	install_sigterm_handler()
	common.log("Starting updater process at " + time.strftime("%d%m%y_%H%M%S"))
	devices = []
	update_loop(devices)

if(__name__ == "__main__"):
	main()

#!/usr/bin/env python3

import os
import time

import common

# NOTE: This module will not check for the validity of last_updates, it will just be
# assumed that they have been checked to be valid. They're only here to
# preserve the unmodified elements of the arrays
class UpdateParams():
	def __init__(self):
		self.device = None
		self.update = None
		self.auth = ("", "")
		self.config = None
		self.now = 0

class ImageDescription():
	def __init__(self):
		self.new_image = ""
		self.zip_url = ""

class NoConnectionError(Exception):
	pass

# Returns the name of the image that was installed
def update(params):
	assert(type(params).__name__ == "UpdateParams")

	device		= params.device
	testset		= params.config.get(device.name, "testset")
	auth		= params.auth
	update		= params.update

	assert(type(update).__name__ == "ImageDescription")

	try:
		_wait_ping_response(device, 10)
	except NoConnectionError:
		common.log("Device %s not powered, booting" % device.name)
		_reboot_device(config, device, hard=True, downtime=30)

	try:
		_flash_image(params.config, device, auth, update.zip_url)
		common.log("Installed new images on %s" % device.name)
		return update.new_image

	except common.RunShError as e:
		common.error(str(e))
		common.log("Failed to install any images on %s" % device.name)
		return None

	except NoConnectionError:
		common.error("No network connection to %s, probably failed to flash" % device.name)
		return None

def _timeout_cmd(device, cmd, timeout):
	# To always allow ample time for software power commands. Sending
	# power commands over SSH is quite wonky, sometimes they will
	# immediately end the SSH connection and sometimes they'll remain
	# hanging.
	SOFT_POWERDOWN_TIMEOUT = 10
	start_time = time.time()

	common.remote_cmd(device, cmd, raise_on_err=False,
	                  timeout=SOFT_POWERDOWN_TIMEOUT)

	sleep_time = start_time + SOFT_POWERDOWN_TIMEOUT - time.time()
	if (sleep_time > 0):
		time.sleep(sleep_time)

def _reboot_device(config, device, hard = False, downtime = 60):
	CAN_IF_KEY = "can_if"
	if (not hard):
		common.log("Doing soft reboot on %s using reboot command" %
		           device.name)
		_timeout_cmd(device, ["reboot"], 10)
	else:
		_timeout_cmd(device, ["poweroff"], 10)
		if (CAN_IF_KEY in config[device.name]):

			interface = config[device.name][CAN_IF_KEY]
			common.log("Doing hard reboot on %s through CAN" %
			           device.name)
			try:
				_can_reboot(config, device, interface)
			except KeyError as e:
				common.error("CAN misconfigured, key %s lacking for device %s. Using tdtool" %
				             (e, device.name))
				_tdtool_reboot(config, device)
		else:
			common.log("Doing hard reboot on %s with tdtool" %
			           device.name)

			_tdtool_reboot(config, device)

def _can_power_event(config, device, interface, power_cmd):
	# Signal will contain spaces ("send KeyPosition=0" or something) and
	# must be chopped up for that reason
	image_type_conf	= config[device.image_type]
	cfg		= os.path.expandvars(image_type_conf["can_cfg"])
	dbc		= os.path.expandvars(image_type_conf["can_dbc"])
	signal		= image_type_conf[power_cmd].split()

	common.run_cmd([common.CAN_SIMULATOR,
	                "-c", cfg,
	                "-d", dbc,
	                "-i", interface] + signal)

def _tdtool_power_event(config, device, power_cmd):
	switch = config[device.name]["power_switch"]
	for _ in range(3):
		common.run_cmd([common.TDTOOL,
		                power_cmd,
		                switch])

def _can_reboot(config, device, interface, downtime = 60):
	_can_power_event(config, device, interface, "can_powerdown")
	time.sleep(downtime)
	_can_power_event(config, device, interface, "can_powerup")

def _tdtool_reboot(config, device, downtime = 60):
	_tdtool_power_event(config, device, "--off")
	time.sleep(downtime)
	_tdtool_power_event(config, device, "--on")

def _wait_ping_response(device, timeout):
	start_time = int(time.time())
	while (int(time.time()) < start_time + timeout):
		rv = common.run_cmd(["ping",
		                     "-c", "1",
		                     device.ip], raise_on_err=False)
		if (rv.retval == 0):
			return

	raise NoConnectionError

def _flash_image(config, device, auth, image_url):
	common.log("Flashing %s on %s" % (image_url, device.name))

	username, password = auth
	common.run_sh(common.PREPARE_FLASHING_SCRIPT,
	              [device.ip, image_url, username, password])

	# Some recovery images may power down themselves instead of rebooting
	# after a successful flashing. If the timeout fails, just assume that
	# the flashing went fine and fire up the device.
	_reboot_device(config, device)
	common.log("Rebooting %s to trigger flashing" % device.name)
	try:
		_wait_ping_response(device, 10 * 60)
		common.log("%s woke up in time after flashing" % device.name)
	except NoConnectionError:
		common.log("%s did not power up after flashing, manual powerup" %
		           device.name)
		_reboot_device(config, device, downtime=30, hard=True)

	common.log("Doing second reboot on %s after flashing" % device.name)
	_reboot_device(config, device)
	_wait_ping_response(device, 2 * 60)

	device.config.set("general", "zip_url", image_url)

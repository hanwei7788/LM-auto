#!/usr/bin/env python3

import shutil
import sys
import common
import configparser
import os
import argparse

def my_path():
	return os.path.dirname(os.path.realpath(__file__))

CONFIG_FILE_TEMPLATE	= "%s.conf"
IMAGE_TYPE_TEMPLATE	= "%s_images"

DEVICE_CONF_TEMPLATE	= "per_device.conf.example"
CONFIG_FILE_WEEKLY	= os.path.join(my_path(), "weekly.conf")
USAGE = "Usage: %s <device name> <image type> <IP> <testset>"

def parse_args():
	parser = argparse.ArgumentParser()
	parser.add_argument("name", help="Name of device")
	parser.add_argument("image_type", help="Image type. Use '' around R&D")
	parser.add_argument("ip", help="Target IP address")
	parser.add_argument("test_set", help="test_set")
	parser.add_argument("power_switch", help="power_switch")
	parser.add_argument("can_if", nargs='?', default='', help="Powerdown or powerup throught CAN")
	args = parser.parse_args()
	return args

def create_config(config_file):
	if os.path.exists(config_file) == False:
		shutil.copyfile(DEVICE_CONF_TEMPLATE, config_file)
		print('Creating new Config')

def weekly_conf(device, config_file):
	if os.path.exists(CONFIG_FILE_WEEKLY) == False:
		shutil.copyfile('weekly.conf.example','weekly.conf') 
		print('Creating weekly.conf')
	config = configparser.ConfigParser()
	config.sections()
	config.read(CONFIG_FILE_WEEKLY)
	config[device.name] = {'ip':device.ip	,
				'config_file':config_file,
				'test_set':device.test_set,
				'power_switch':device.power_switch,
				'can_if':device.can_if}
	with open(CONFIG_FILE_WEEKLY,'w') as configfile:
		config.write(configfile)

def main(argv):
	device = parse_args()
	config_file = CONFIG_FILE_TEMPLATE % device.name
	if device == None:
		return 1	
	with common.FileLock() as lock:
		if lock.acquire():
			weekly_conf(device,config_file)
			create_config(config_file)
		else:
			print("Cannot add devices while updater is running!",
			      file=sys.stderr)
			return 2
if __name__ == "__main__":
	sys.exit(main(sys.argv))


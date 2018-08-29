#!/usr/bin/env python3

import threading

class Device:
	def __init__(self, name, config, config_fname, ip, image_type):
		self.name = name
		self.config = config
		self.config_fname = config_fname
		self.ip = ip
		self.image_type = image_type
		self.autotest = None
		self.test_kill_switch = threading.Event()

#!/usr/bin/env python3

import threading
import time
import requests
import types

import tests
import updater
import common

class NoImageNameError(Exception):
	pass

# Return a tuple with (image_name, zip_url): image_name is the plain name
# of the image without file extensions, and zip_url is the whole url to
# the zip to be flashed
def get_image_name(latest):
	response = requests.get(latest, auth=common.get_auth("dav"))
	urls = response.content.decode("UTF-8").splitlines()
	for zip_url in urls:

		# Cut off the extension from image file name
		if(zip_url.endswith(common.ZIP_EXTENSION)):
			last_slash = zip_url.rfind("/")
			image_name = zip_url[last_slash + 1:-len(common.ZIP_EXTENSION)]
			return (image_name, zip_url)

	raise NoImageNameError(latest)

# The versions on the device can never be newer than the newest
# ones online, so (latest_online != latest_onboard) will mean
# that an update is due
#
# Returns an ImageDescription object if an update is due, None otherwise
def check_new_images(latest, onboard, now, enu, new_overrides_old, tests_alive):
	if(latest == ""):
		return None
	try:
		online_img, zip_url = get_image_name(latest)
		newer_image_found = online_img != onboard
		update_due = new_overrides_old or now >= enu

		if(newer_image_found and (update_due or not tests_alive)):
			update = updater.ImageDescription()
			update.new_image = online_img
			update.zip_url = zip_url
			return update
		return None

	except NoImageNameError as e:
		common.error("No image names found from " + str(e))
		return None

def let_new_override_old(config, priority):
	overriding = common.config_get_list(config, "general", "new_overrides_old")
	return priority in overriding

# Ok to flash an image at all in this stage of the currently ongoing test?
def get_schedule(device, config):
	current_image = device.config.get("general", "image_type")
	current_image_updated = device.config.get("last_update", current_image)
	testset = config.get(device.name, "testset")
	params = [current_image_updated, testset]

	result = types.SimpleNamespace()
	try:
		result = common.run_sh(common.CHECK_SCHEDULE_SCRIPT, params)
		flags_str = result.stdout.decode("UTF-8")
	except common.RunShError as e:
		common.error("Error in reading schedule for %s: %s" % \
		             (device.name, e.content.stderr.decode("UTF-8")))
		result.allow_update = False
		result.upload_test_results = False
		return result

	flags = flags_str.strip().split(common.SCHEDULE_FLAG_SEPARATOR)
	if(len(flags) != 2):
		common.error("Schedule is errorneous for testset %s? Got a return value %s" % \
		             (testset, flags_str))
		result.allow_update = False
		result.upload_test_results = False
	else:
		result.allow_update		= flags[0] != "0"
		result.upload_test_results	= flags[1] != "0"
	return result

def check_tests(test_thread):
	try:
		return test_thread.isAlive()
	except AttributeError:
		return False

# Check through the priorities until an image due for install is found
def check_and_update(device, config, run_tests):
	priorities = common.config_get_list(config, "general", "priority")
	update_period = common.int_nothrow(config.get("general", "update_period"))
	now = int(time.time())

	tests_alive = check_tests(device.autotest)
	schedule = get_schedule(device, config)
	if(tests_alive and not schedule.allow_update):
		common.log("Schedule forbids updating %s right now" % device.name)
		return

	for priority in priorities:

		# If there are no newer images for this priority:
		# 1) If this image have been in use for the whole test
		#    duration, check lower priorities
		# 2) If the tests are still ongoing, abort here
		latest_list = config.get(device.image_type, priority)
		latest_onboard = device.config.get("latest_image", priority)
		last_update = common.int_nothrow(device.config.get("last_update", priority))
		enu = last_update + update_period

		update = check_new_images(latest_list,
		                          latest_onboard,
		                          now,
		                          enu,
		                          let_new_override_old(config, priority),
					  tests_alive)
		if(update == None):
			if(now >= enu):
				common.log(" Could update %s to %s but no new images available" % \
				      (device.name, priority))
				continue
			else:
				common.log("%s will still run %s" % (device.name, priority))
				break

		last_update = now
		upload_results = schedule.upload_test_results or not tests_alive
		tests.stop_tests_and_report(device, upload_results)

		params = updater.UpdateParams()
		params.device		= device
		params.update		= update
		params.auth		= common.get_auth("dav")
		params.config		= config
		params.now		= now

		new_image = updater.update(params)

		if(new_image):
			latest_onboard = new_image
			if(run_tests):
				testset = config.get(device.name, "testset")
				tests.start_tests(device, config, testset)

			device.config.set("last_update", priority, str(last_update))
			device.config.set("latest_image", priority, latest_onboard)
			device.config.set("general", "image_type", priority)
			common.write_config(device.config, device.config_fname)

			common.log("Updated %s to %s" % (device.name, priority))
		else:
			common.log("Failed to update %s to %s, skipping" % \
				(device.name, priority))
		break
	else:
		common.log("No updates for %s" % device.name)

# Check and update all devices where an update is due, on any priority
def check_updates_all_devices(devices, config, run_tests):
	threads = []
	for device in devices:
		t = threading.Thread(target=check_and_update,
		                     args=(device, config, run_tests))
		t.start()
		threads.append(t)

	return threads

def wait_threads(threads):
	for thread in threads:
		thread.join()

def run_update_cycle(devices, config, run_tests = True):
	with common.FileLock() as updater_lock:
		try:
			if(updater_lock.acquire()):
				threads = check_updates_all_devices(devices,
				                                    config,
				                                    run_tests)
				wait_threads(threads)
				updater_lock.release()
			else:
				common.log("Error: Another update process ongoing, won't run before it finishes")

		# Unlock on SIGTERM but do still forward it. Apparently the
		# destructor will not otherwise be called if lock is being held
		# when killed with SIGTERM by user
		except common.SigTermCaught:
			updater_lock.release()
			raise

#!/usr/bin/env python3

import subprocess
import threading
import signal

import common

def stop_tests_and_report(device, upload_results):
	_stop_tests(device)
	if(upload_results):
		common.log("Uploading test results for " + device.name)
		if(device.autotest != None):
			# Upload signal
			device.autotest.send_signal(signal.SIGUSR1)
			device.autotest.join()
	else:
		common.log("No need to upload test results for " + device.name)

def _stop_tests(device):
	device.test_kill_switch.set()
	if(device.autotest != None):
		device.autotest.join()
		device.autotest = None

# Add the currently running waiter threads to the device's tests list and also
# a kill switch for forcing all the threads to end the tests they're waiting
def start_tests(device, config, testset):
	common.log("Starting the tests %s on %s" % (testset, device.name))

	autotest_p = _start_autotests(device, config)
	kill_switch = threading.Event()

	autotest_t = threading.Thread(target=_wait_process, args=(autotest_p, kill_switch))
	autotest_t.start()
	device.autotest = autotest_t
	device.test_kill_switch = kill_switch

def _start_autotests(device, config):
	testset	= config.get(device.name, "testset")
	params	= [device.name, device.ip, testset]
	cmd = common.gen_run_sh_cmd(common.START_AUTOTESTS_SCRIPT, params)
	return common.run_nowait(cmd)

def _wait_process(process, kill_switch):
	process_alive = True
	while(process_alive):
		process.poll()
		process_alive = process.returncode == None
		if(kill_switch.is_set()):
			process.terminate()
		try:
			process.wait(timeout=1)
		except subprocess.TimeoutExpired:
			pass

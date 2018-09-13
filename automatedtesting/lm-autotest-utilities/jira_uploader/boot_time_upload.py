#!/usr/bin/python3

import sys
import os
import uploader_common
import shutil
import requests

def my_path(): return os.path.dirname(os.path.realpath(__file__))
sys.path.append(os.path.join(my_path(), "..", "common"))
sys.path.append(os.path.join(my_path(), "..", "autotestservice"))
import jiralib
import global_config
import sufu_csv2graph as c2g

DEFAULT_CONF_FILE = os.path.join(my_path(), "jira_upload_conf.json")
DAV_SUCCESS_VALUES = [200, 201, 202, 204]
GRAPH_WID = 1280
GRAPH_HEI = 1024

cmdline_args = [
	(("-n", "--sut_name"), {
	"help": "Name of the target system under test (SUT)",
	"required": True,
	}),
	(("-t", "--test_id"), {
	"help": "Autotest ID",
	"required": True,
	}),
	(("-y", "--type"), {
	"help": "Type of the image. (example: \"nightly\", \"smoke\", \"release\"...)",
	"required": True,
	}),
	(("-c", "--conf"), {
	"help": "(Optional) Configuration file URL. Default: %s" % DEFAULT_CONF_FILE,
	"default": DEFAULT_CONF_FILE,
	}),
	(("-s", "--skip_jira"), {
	"help": "(Optional)Flag to skip the upload into JIRA",
	"default": False,
	"action": "store_true"
	})
]

class BootUploadError(Exception):
	pass

def get_image_measurement(project, conf_file):
	try:
		conf_data = uploader_common.read_json(conf_file)
		return conf_data["project"][project]
	except:
		raise BootUploadError("Unable to fetch measurement info.\n" \
					"Check jira_upload_conf.json")

#The amount of previous images is set in NUM_PREVIOUS_IMAGES.
#Return list is reversed so that the graph drawn is in chronological order (Oldest image left, newest on the right)
def get_previous_images(image, nightly_path, images_to_get):
	prev_images = []
	#Strip away the version number and date-time stuff
	project_type = image.split("-")[2] + "-" + image.split("-")[3]
	list_dirs = os.listdir(nightly_path)
	for dir in list_dirs:
		if project_type in dir and dir.endswith(".zip"):
			prev_images.append(dir)

	prev_images.sort(reverse=True)
	result = []
	for image in prev_images:
		#If there is no boots.csv for certain image, ignore it
		if not os.path.exists(os.path.join(nightly_path, image, "boots.csv")):
			continue
		result.append(image)
		if len(result) == images_to_get:
			break

	result.reverse()
	return result

def get_jira_key(file):
	try:
		key_file = uploader_common.read_json(file)
		key = key_file['key']
	except:
		print("No Jira issue key for this image. Skipping Jira upload.")
		return

	return key

def draw_graph(images, issues_path, out_file, measurement):
	print("Plotting boot time graph...")
	boots_list = []
	for img in images:
		item = (img, os.path.join(issues_path, img, "boots.csv"))
		boots_list.append(item)
	graph_data = c2g.gen_graph_data(boots_list, measurement)
	plot_data = c2g.plot_data(out_file, graph_data, GRAPH_WID, GRAPH_HEI)
	print("Plotting OK")

def upload_graph_to_jira(jira, file, key):
	print("Uploading graph to JIRA issue:", key, "...")
	if not os.path.exists(file):
		return
	with jiralib.MultipleFileManager() as fm:
		fm.add_file(file)
		try:
			result = jira.upload_files(key, fm)
			print("Uploaded graph to JIRA")
		except:
			raise BootUploadError("Failed to upload graph to JIRA")
	print("JIRA upload OK")

def upload_graph_to_dav(dav_url, fpath, auth):
	print("Uploading graph to DAV:", dav_url, "...")
	fname = os.path.basename(fpath)
	dav_path = os.path.join(dav_url, fname)
	with open(fpath, "rb") as file:
		r = requests.put(dav_path, data=file, auth=auth)
		if r.status_code not in DAV_SUCCESS_VALUES:
			raise BootUploadError("Bad DAV request status code", r.status_code)
	print("DAV upload OK")

def get_test_properties(test_type):
	conf = uploader_common.read_json(global_config.get_path())
	return conf["test_types"][test_type]

def boot_time_upload(sut_name, test_id, test_type, skip, conf_file=DEFAULT_CONF_FILE):
	print("Starting Boot Time Upload for", sut_name)
	try:
		auth = uploader_common.get_jira_auth()
		jira_url = global_config.get_conf("urls", "jira")

	except (IOError, PermissionError, ArgumentError, FileNotFoundError, json.decoder.JSONDecodeError, KeyError) as e:
		print("Error when reading auth from config:", file=sys.stderr)
		uploader_common.print_exc(e)
		sys.exit(1)

	test_props = get_test_properties(test_type)

	try:
		jira = jiralib.JIRA(jira_url, auth)
		argotestroot = uploader_common.get_path_from_conf("argotest", conf_file)
		sutfolder_path = os.path.join(argotestroot, "TestReports_" + sut_name)
		image_url = uploader_common.read_file(os.path.join(	sutfolder_path, \
									"last_installed_zip.txt")).strip()
		image = os.path.basename(image_url)
		project = image.split("-")[2]

		measurement = get_image_measurement(project, conf_file)
		try:
			issues_path = os.path.join(argotestroot, test_props["issues_dir"])
		except TypeError as e:
			print("Bad image_type:", e)
			sys.exit(1)
		except KeyError as e:
			print("No issues_dir key for image type " + test_type, e)
			sys.exit(1)

		master_folder = os.path.join(issues_path, image)
		os.makedirs(master_folder, exist_ok=True)
		shutil.copyfile(os.path.join(sutfolder_path, test_id, "boots.csv"), \
				os.path.join(master_folder, "boots.csv"))

		#Fetch information how many images are drawn into the graph
		images_to_draw = uploader_common.read_json(conf_file)["num_images_boot_time"]
		#Fetch information about the previous images
		images_to_draw = get_previous_images(image, issues_path, images_to_draw)
		key = get_jira_key(os.path.join(master_folder, image + "_key.json"))
		#Use sufu_csv2graph to draw some lines
		output_filename = test_type + "-" + project + "-BootTime.png"
		result_image_path = os.path.join(master_folder, output_filename)
		draw_graph(images_to_draw, issues_path, result_image_path, measurement)
		if key and not skip:
			upload_graph_to_jira(jira, result_image_path, key)
		dav_url = uploader_common.get_url_from_conf("dav", conf_file)
		upload_graph_to_dav(dav_url, result_image_path, auth)
		if (test_props.get("release", False)):
			shutil.copyfile(path.join(master_folder, output_filename), path.join(sutfolder_path, test_id, output_filename))

	except BootUploadError as e:
		print("BootUploadError:", e)
		return 1

	return 0

def main(argv):
	args = uploader_common.parse_args(argv, cmdline_args)
	retval = boot_time_upload(args.sut_name, args.test_id, args.type, args.skip_jira, args.conf)
	return retval

if __name__ == "__main__":
	sys.exit(main(sys.argv))

import os
import json
import requests

ATTACHMENT_PATH_TEMPLATE	= "/rest/api/2/issue/%s/attachments"
COMMENT_PATH_TEMPLATE		= "/rest/api/2/issue/%s/comment"
DELETE_ATTACHMENT_PATH_TEMPLATE	= "/rest/api/2/attachment/%s"
ASSIGN_ISSUE_PATH_TEMPLATE	= "/rest/api/2/issue/%s/assignee"
GET_ISSUE_PATH_TEMPLATE		= "/rest/api/2/issue/%s"
CREATE_ISSUE_PATH		= "/rest/api/2/issue"
XRAY_IMPORT_PATH		= "/rest/raven/1.0/import/execution"

class JIRAException(Exception):
	pass

class JIRA():
	url = None
	auth = None

	def __init__(self, url, auth):
		self.url = url
		self.auth = auth

	def upload_comment(self, issue_key, comment):
		data = json.dumps({"body": comment})

		url = self.url + COMMENT_PATH_TEMPLATE % issue_key
		headers = {"Content-Type"	: "application/json",
		           "Accept"		: "application/json",
		           "X-Atlassian-Token"	: "no-check"}

		r = requests.post(url,
		                  data = data,
		                  auth = self.auth,
		                  headers = headers)

		if (r.status_code == requests.codes.created):
			return r.json()["id"]
		else:
			raise JIRAException("Failed to write comment: " + r.reason)

	# file_manager: A MultipleFileManager containing all the files you want
	# to upload
	def upload_files(self, issue_key, file_manager):
		url = self.url + ATTACHMENT_PATH_TEMPLATE % issue_key
		headers = {"X-Atlassian-Token": "no-check"}

		r = requests.post(url,
		                  files		= file_manager.get_list(),
		                  auth		= self.auth,
		                  headers	= headers)

		if (r.status_code == requests.codes.ok):
			result = []
			for f in r.json():
				current = {"filename": f["filename"], "id": f["id"]}
				result.append(current)
			return result
		else:
			raise JIRAException("Failed to upload attachments: %s" %
			                    r.reason)

	# file_id: The JIRA id of a file as a str, for example "25234"
	def delete_file(self, file_id):
		url = self.url + DELETE_ATTACHMENT_PATH_TEMPLATE % str(file_id)
		headers = {"X-Atlassian-Token": "no-check"}

		r = requests.delete(url,
		                    auth	= self.auth,
		                    headers	= headers)

		if (r.status_code != requests.codes.no_content):
			raise JIRAException("Failed to delete file %s: %s" %
					    (file_id, r.reason))

	# description: A JSON object containing the necessary information to
	# create a JIRA issue, for example:
	# {
	# 	"fields": {
	#		 "summary": "Test task",
	#		 "project": {
	#			 "key": "XTP"
	#		 },
	#		 "issuetype": {
	#			 "name": "Test Execution"
	#		 },
	#		 "assignee": {
	#			 "name": "autotest@nomovok.com"
	#		 }
	#	 }
	# }
	def create_issue(self, description):
		url = self.url + CREATE_ISSUE_PATH
		headers = {"X-Atlassian-Token": "no-check"}

		r = requests.post(url,
		                  json		= description,
		                  auth		= self.auth,
		                  headers	= headers)

		if (r.status_code == requests.codes.created):
			return r.json()
		else:
			raise JIRAException("Failed to create issue: %s" %
			                    r.reason)

	# issue_key: A string identifying the issue (eg. "XTP-3260")
	# assignee: A dict identifying a user, for example:
	# 	{"name": "autotest@nomovok.com"}
	def assign_issue(self, issue_key, assignee):
		url = self.url + ASSIGN_ISSUE_PATH_TEMPLATE % issue_key
		headers = {"Content-Type": "application/json"}

		r = requests.put(url,
				 json		= assignee,
				 auth		= self.auth,
				 headers	= headers)

		if (r.status_code != requests.codes.no_content):
			raise JIRAException("Failed to assign %s to %s: %s" %
					    (issue_key, repr(assignee), r.reason))

	def get_issue(self, issue_key):
		url = self.url + GET_ISSUE_PATH_TEMPLATE % issue_key
		headers = {"Content-Type": "application/json"}

		r = requests.get(url,
				 auth		= self.auth,
				 headers	= headers)

		if (r.status_code == requests.codes.ok):
			return r.json()
		else:
			raise JIRAException("Failed to get %s %s" %
					    (issue_key, r.reason))

	def import_xray(self, issue_key, xray_file):
		url = self.url + XRAY_IMPORT_PATH
		headers = {"Content-Type": "application/json"}

		with open(xray_file, "r") as f:
			report = json.load(f)
		report["testExecutionKey"] = issue_key

		r = requests.post(url,
		                  json		= report,
		                  auth		= self.auth,
		                  headers	= headers)

		if (r.status_code == requests.codes.ok):
			return r.json()["testExecIssue"]
		else:
			raise JIRAException("Failed to import Xray file: %s" %
			                    r.reason)

	def new_xray_execution(self, xray_file, issue_description):
		issue = self.create_issue(issue_description)
		return self.import_xray(issue["key"], xray_file)

class MultipleFileManager():
	def __init__(self):
		self._files = []

	def __enter__(self):
		return self

	def add_directory(self, dirname):
		for fname in os.listdir(dirname):
			fpath = dirname + "/" + fname

			if (os.path.isdir(fpath)):
				self.add_directory(fpath)
			else:
				self.add_file(fpath)

	def add_file(self, fname):
		f = open(fname, "rb")
		self._files.append(f)

	# Give a list with full file descriptions (name, file handle, file
	# type, custom headers). Necessary because we want to use a custom
	# Content-Disposition header here.
	def get_list(self):
		result = []
		for f in self._files:
			file_desc = (os.path.basename(f.name),
			             f,
			             "text/plain",
			             {"Content-Disposition": "inline"})

			result.append(("file", file_desc))
		return result

	def __exit__(self, *args):
		for f in self._files:
			f.close()
		self._files.clear()

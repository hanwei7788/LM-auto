#!/usr/bin/python
###############################################################################
#
# This script can be used to automatically replace license header placeholders
# with a valid information from git logs. This uses gitpython module to fetch
# the git blame information for name and email values.
#
# Author: Juhapekka Piiroinen <juhapekka.piiroinen@link-motion.com>
#
# (C) 2016 Link Motion Oy
# All Rights Reserved.
###############################################################################
from git import Repo
import datetime
import argparse
import os
from os.path import join, getsize
import re

SCRIPTPATH = os.path.dirname(os.path.realpath(__file__))


class AutoLicenseTool(object):
    def __init__(self, template="ui"):
        self.template = template
        self._DETECT_LICENSEHEADER = self._read_template(
            "licenseheader/detect")
        self._INPUT_LICENSEHEADER = self._read_template(
            "licenseheader/input")
        self._INPUT_AUTHORLINE = self._read_template(
            "licenseheader/author/input")
        self._OUTPUT_AUTHORLINE = self._read_template(
            "licenseheader/author/output")
        self._INPUT_FILENAMELINE = self._read_template(
            "licenseheader/filename/input")
        self._OUTPUT_FILENAMELINE = self._read_template(
            "licenseheader/filename/output")
        self._PREFIXES = self._read_template("prefixes").split("\n")
        self._BLACKLIST = self._read_template("blacklist").split("\n")

    def _read_template(self, templateName):
        return open("%s/../templates/%s/%s" % (SCRIPTPATH,
                                               self.template,
                                               templateName
                                               )).read()

    def author_list(self, fileName, commitVer="HEAD", repoName="."):
        retval = []
        repo = Repo(repoName)
        changes = repo.blame(commitVer, fileName)
        foundNames = []
        for change in changes:
            commit = change[0]
            email = commit.author.email
            if not email:
                email = "notset"
            name = commit.author.name
            if name in foundNames:
                continue
            foundNames.append(name)
            date_epoch = commit.authored_date
            date = datetime.datetime.fromtimestamp(date_epoch).strftime(
                   '%Y-%m-%d %H:%M:%S')
            retval.append({"name": name, "email": email, "date": date})
        return retval

    def is_blacklisted(self, value):
        # if the value equals to the blacklist
        if value in self._BLACKLIST:
            return True
        # go thru all lines in the blacklist
        for bl in self._BLACKLIST:
            # lets remove whitespaces and skip if the was empty
            bl = bl.strip()
            if not bl:
                continue
            # the real check with regexp
            if re.search(bl, value):
                return True
        return False

    def list_all_files(self, rootdir):
        retval = []
        for root, dirs, files in os.walk(rootdir):
            for name in files:
                retval.append(os.path.join(root, name))
        return retval

    def filter_filelist(self, filelist, allowed_extensions):
        retval = []
        for index, file in enumerate(filelist):
            if self.is_blacklisted(file):
                continue
            fileName, extension = os.path.splitext(file)
            if extension and (extension in allowed_extensions):
                if self.has_template_licenseheader(file):
                    retval.append(file)
        return retval

    def filter_filelist_no_header(self, filelist, allowed_extensions):
        retval = []
        for index, file in enumerate(filelist):
            if self.is_blacklisted(file):
                continue
            fileName, extension = os.path.splitext(file)
            if extension and (extension in allowed_extensions):
                if (not self.has_template_licenseheader(file) and
                   not self.detect_licenseheader(file)):
                    retval.append(file)
        return retval

    def has_template_licenseheader(self, file):
        filecontent = open(file).read()
        return (filecontent.startswith(self._INPUT_LICENSEHEADER))

    def detect_licenseheader(self, file):
        filecontent = open(file).read()
        return (filecontent.startswith(self._DETECT_LICENSEHEADER))

    def auto_update_licenseheader(self, file, authors):
        fileName = os.path.basename(file)
        authorsContent = ""
        for index, author in enumerate(authors, start=1):
            authorsContent += (self._OUTPUT_AUTHORLINE % (
                               author["name"].encode('ascii', 'ignore'),
                               author["email"].encode('ascii', 'ignore')
                               )).encode('ascii', 'ignore')
            if index < len(authors):
                authorsContent += "\n"
        filecontent = open(file).read()
        filecontent = filecontent.replace(
            self._INPUT_AUTHORLINE,
            authorsContent)
        filecontent = filecontent.replace(
            self._INPUT_FILENAMELINE,
            self._OUTPUT_FILENAMELINE % fileName)
        with open(file, "w") as writer:
            writer.write(filecontent)
            writer.close()

    def auto_add_licenseheader(self, file, authors):
        filecontent = open(file).read()
        with open(file, "w") as writer:
            writer.write(self._INPUT_LICENSEHEADER)
            writer.write(filecontent)
            writer.close()

    def run_update(self, rootPath="."):
        filelisting = self.list_all_files(rootPath)
        filelisting = self.filter_filelist(filelisting, self._PREFIXES)

        for file in filelisting:
            print(" * %s" % file)
            authors = self.author_list(fileName=file, repoName=rootPath)
            self.auto_update_licenseheader(file, authors)

    def run_add_header(self, rootPath="."):
        filelisting = self.list_all_files(rootPath)
        filelisting = self.filter_filelist_no_header(filelisting,
                                                     self._PREFIXES)
        for file in filelisting:
            if self.detect_licenseheader(file):
                print(" [skip] %s has already a license header." % file)
                continue
            print(" * %s" % file)
            authors = self.author_list(fileName=file, repoName=rootPath)
            self.auto_add_licenseheader(file, authors)


if __name__ == '__main__':
    # check WORKPATH env flag
    workPath = os.environ.get('WORKPATH')
    if workPath:
        os.chdir(workPath)

    # check our arguments
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--add-missing-headers',
        '-a',
        dest='add',
        action='store_true',
        help="Add missing license header placeholders",
        default=False
        )
    parser.add_argument(
        '--update-headers',
        '-u',
        dest='update',
        action='store_true',
        help="Update all placeholder license headers",
        default=False
        )
    parser.add_argument(
        '--src',
        dest='src',
        type=str,
        help='Source path which you would like to traverse.'
        )
    parser.add_argument(
        '--template',
        dest='template',
        type=str,
        help='The template type'
        )
    args = parser.parse_args()
    if not args.src or not args.template:
        parser.print_help()
    else:
        al = AutoLicenseTool(template=args.template)
        if args.add is True:
            print("Adding missing license headers in %s" % args.src)
            al.run_add_header(rootPath=args.src)
        if args.update is True:
            print("Updating license headers in %s" % args.src)
            al.run_update(rootPath=args.src)

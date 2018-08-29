#!/usr/bin/env python3

import requests
import sys
import json
import os
import time
from urllib.parse import urljoin

#Usage message
def usage(argv):
    print("Usage: %s <sut_name> <image_to_flash>" % argv[0])
    print("Usage: If <image_to_flash> is not provided, latest will be used")

#Get usb address from image.conf
def get_usb_address(sut_name):
    conf_location = os.path.join(os.getenv("HOME"), "automatedtesting", "argo_functional_tests", "TestReports_" + sut_name, "image.conf")
    try:
        imageconf = open(conf_location, 'r').read()
        paths = imageconf.splitlines()
        for path in paths:
            p = path.split("=", 1)
            if(p[0] == "USBOTG"):
                return p[1]
        return ""
    except FileNotFoundError:
        print("image.conf under device " + sut_name + " not found")
        sys.exit(1)

#Function to check the flashing status
def flashing_status(FlashApi, flashingId):
    #Max flashing time in seconds. This will be fetched from configs with the new system
    max_flash_time = 720
    #Interval that the status of the flashing is checked in seconds, this will be fetched from configs with the new system
    flash_status_check_interval = 30
    flashing_time_elapsed = 0
    while flashing_time_elapsed <= max_flash_time:
        status = requests.get(urljoin(FlashApi, "flashings/" + flashingId))
        if (status.status_code == 404):
            print("Error: Unable to find specific flashing id (404")
            return 1
        elif (status.json()["status"] == "Passed"):
            print("Device flashed successfully")
            return 0
        elif (status.json()["status"] == "Failed"):
            print("Flashing failed: " + status.json()["errorMessage"])
            return 1
        if status.json()["progressPercentage"] is None:
            print("Starting flashing")
        else:
            print("Flashing: " + str(status.json()["progressPercentage"]) + "%")
        time.sleep(flash_status_check_interval)
        flashing_time_elapsed = flashing_time_elapsed + flash_status_check_interval
    print("Device flashing takes too long. Something must have broken.")
    return 1

#Flash function which also monitor progress
def flash(usbotg, image_to_flash, FlashApi):
    print("Trying to flash image: " + image_to_flash)
    response = requests.post(urljoin(FlashApi, "flashings/" + usbotg), json = { "PackageId": image_to_flash})
    if (response.status_code == 400):
        print("Error: Null or empty package Id (400)")
        return 1
    elif (response.status_code == 404):
        print("Error: Unable to find package or port ID (404)")
        return 1
    elif (response.status_code == 403):
        print("Error: Device is busy (403)")
        return 1
    elif (response.status_code == 500):
        print("Error: WindowsPC is having difficulties with the request")
        return 1
    flashingId = response.json()["flashingId"]
    return flashing_status(FlashApi, flashingId)

def latest(FlashApi):
    return requests.get(urljoin(FlashApi, "packages/flash")).json()[-1]["id"]

def main(argv):
    try:
        sut_name = argv[1]
    except IndexError:
        usage(argv)
        return 1
    #FlashApi address. This can be fetched from configs in the new system
    FlashApi = "http://192.168.2.10:5000/api/"
    image_to_flash = ""
    if len(argv) == 3:
        image_to_flash = argv[2]
    #Lets check that USBOTG is specified in config file
    usbotg = get_usb_address(sut_name)
    if usbotg == "":
        print("USBOTG not defined in " + sut_name + " image.conf")
        return 1
    #Get the latest if desired image was not specified
    if image_to_flash == "":
        image_to_flash = latest(FlashApi)
    return flash(usbotg, image_to_flash, FlashApi)

if (__name__ == "__main__"):
    sys.exit(main(sys.argv))

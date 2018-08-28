#! /usr/bin/env python3
#encoding: utf-8
#Author By Han Wei

# This script aim to cycle 100 timies switch testing on wifi feature.
import unittest, os, sys
from time import sleep
from appium import webdriver
import logging

desired_caps = {}
# desired_caps['device'] = 'android'
desired_caps['deviceName'] = 'emulator-5554'
desired_caps['platformName'] = "Android"
# desired_caps['browseName'] = ''
desired_caps['Version'] = '7.1.1'
# 不需要每次都安装
desired_caps['noReset'] = True
# 测试应用程序的包名
desired_caps['appPackage'] = "com.android.launcher"
desired_caps['appActivity'] = "com.android.launcher2.Launcher"

# add chinese language support
desired_caps['unicodeKeyboard'] = True
desired_caps['resetKeyboard'] = True

driver = webdriver.Remote("http://127.0.0.1:4723/wd/hub", desired_caps)
#driver = webdriver.Remote()

if not driver:
    print ("error")
    sys.exit(1)



class wificlass:


    def __init__(self):
       # enter wifi page from home page
        driver.find_element_by_accessibility_id("Apps").click()
        sleep(2)
        driver.find_element_by_xpath("//android.widget.TextView[@text='Settings']").click()

        i = 0
        screen_width = driver.get_window_size()['width']
        screen_height = driver.get_window_size()['height']
        x1 = screen_width * 0.5
        x2 = screen_width * 0.5

        y1 = screen_height * 0.2
        y2 = screen_height * 0.8

        while i < 10:
            try:
                driver.find_element_by_xpath("//android.widget.TextView[@text='Wi‑Fi']")
                break
            except Exception as e:
                driver.swipe(x1, y1, x2, y2)
                i = i + 1

        # Click wifi button to enter wifi settings page
        driver.find_element_by_xpath("//android.widget.TextView[@text='Wi‑Fi']").click()
        curren_status = driver.find_element_by_id("com.android.settings:id/switch_text").text


    def wifi_status(self):

        wifi_status = driver.find_element_by_id("com.android.settings:id/switch_text").text

        return wifi_status


    def wifi_switch(self):

        status = self.wifi_status()

        elm = driver.find_element_by_id("com.android.settings:id/switch_widget")
        x = elm.location['x']
        y = elm.location['y']

        if status == "Off":
            # Enable wifi
            # driver.swipe(961, 87, 989, 92)
            driver.swipe(x + 5, y + 10, x + 30, y + 10)
            driver.implicitly_wait(15)
            driver.find_element_by_xpath("//android.widget.TextView[@text='nqwifi']")
            sleep(3)
        else:
            # Disable wifi
            # driver.swipe(989, 92, 961, 87)
            driver.swipe(x + 30, y + 10, x + 5, y + 10)
            sleep(3)


    def wifi_cycle_switch(self,counts):
        self.counts = counts
        i = 0
        while i < self.counts:
            print ("Cycle: ", i )
            self.wifi_switch()
            i = i + 1



    def wifi_connect(self):
        wifi_status = self.wifi_status()

        try:


            driver.find_element_by_id("android:id/summary")

        except Exception as e:
             pass

        else:

            driver.find_element_by_xpath("//android.widget.TextView[@text='nqwifi']").click()
            driver.find_element_by_id("android:id/button3").click()

        if wifi_status == "Off":
            self.wifi_switch()

        driver.implicitly_wait(10)
        driver.find_element_by_xpath("//android.widget.TextView[@text='nqwifi']").click()
        driver.find_element_by_id("com.android.settings:id/password").send_keys("3216549870")
        driver.find_element_by_id("android:id/button1").click()
        driver.implicitly_wait(10)
        result = driver.find_element_by_id("android:id/summary").text
        if result == "Connected":
            print("wifi connection works well!")
            return True
        else:
            print("Wifi connection doesn't work normally!")



if __name__ == '__main__':

    obj = wificlass()
    obj.wifi_cycle_switch(100)
    #obj.wifi_connect()














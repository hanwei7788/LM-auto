#! /usr/bin/env python3
#encoding: utf-8
#Author By Han Wei


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

driver.find_element_by_accessibility_id("Apps").click()
sleep(2)
driver.find_element_by_xpath("//android.widget.TextView[@text='Settings']").click()

i=0
screen_width = driver.get_window_size()['width']
screen_height = driver.get_window_size()['height']
x1 = screen_width*0.5
x2 = screen_width*0.5

y1 = screen_height*0.2
y2 = screen_height*0.8


while i < 10:
    try:
        driver.find_element_by_xpath("//android.widget.TextView[@text='Wi‑Fi']")
        break
    except Exception as e:
        driver.swipe(x1, y1, x2, y2)
        i = i + 1

#Click wifi button to enter wifi settings page
driver.find_element_by_xpath("//android.widget.TextView[@text='Wi‑Fi']").click()

wifi_status = driver.find_element_by_id("com.android.settings:id/switch_text").text

elm = driver.find_element_by_id("com.android.settings:id/switch_widget")
x = elm.location['x']
y = elm.location['y']


if wifi_status == "Off":
    # Enable wifi
    #driver.swipe(961, 87, 989, 92)
    driver.swipe(x+5, y+10, x+30, y+10)
    sleep(3)
else:
    #Disable wifi
   # driver.swipe(989, 92, 961, 87)
    driver.swipe(x+30, y+10, x+5, y+10)
    sleep(3)





#! /usr/bin/env python3
#encoding: utf-8
#Author By Han Wei

import unittest
import time
from appium import webdriver
import tool.lm_logger



# from extend import Appium_Extend

class WifiClass(unittest.TestCase):

    def setUp(self):
        print("SetUp begins.")
        logger.info("tests setUp begins..........")
        self.driver.implicitly_wait(3)
        #self.driver.find_element_by_xpath("//*[@content-desc='Apps']").click()
        self.driver.find_element_by_accessibility_id("Apps").click()
        time.sleep(2)
        self.driver.find_element_by_xpath("//android.widget.TextView[@text='Settings']").click()

        i = 0
        screen_width = self.driver.get_window_size()['width']
        screen_height = self.driver.get_window_size()['height']
        x1 = screen_width * 0.5
        x2 = screen_width * 0.5

        y1 = screen_height * 0.2
        y2 = screen_height * 0.8

        while i < 10:
            try:
                self.driver.find_element_by_xpath("//android.widget.TextView[@text='Wi‑Fi']")
                break
            except Exception as e:
                self.driver.swipe(x1, y1, x2, y2)
                i = i + 1

        self.driver.find_element_by_xpath("//android.widget.TextView[@text='Wi‑Fi']").click()
       # self.curren_status = self.driver.find_element_by_id("com.android.settings:id/switch_text").text

    def tearDown(self):
        print("test tear down start........")
        logger.info("test tear down start........")
        self.driver.keyevent(3)
        #self.driver.quit()
        time.sleep(2)

    # 初始化环境
    @classmethod
    def setUpClass(cls):

        print("Class setUp start.......")
        logger.info("Class setUp start.......")
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

        cls.driver = webdriver.Remote("http://localhost:4723/wd/hub", desired_caps)
        # self.extend = Appium_Extend(self.driver)



    @classmethod
    def tearDownClass(cls):
        print("class quit began.....")
        cls.driver.quit()


    def test_wifi_a_status(self):

        print("Get status now.....")
        logger.info("test_wifi_a_status begins...............")
        logger.info("Get status now.....")

        wifi_status = self.driver.find_element_by_id("com.android.settings:id/switch_text").text

        print("current wifi status is :", wifi_status)
        logger.info("Get status now.....")


        return wifi_status

    def test_wifi_b_switch(self):

        print("Wifi switch now......")
        loggger.info("Wifi switch now......")

        status = self.test_wifi_a_status()

        elm = self.driver.find_element_by_id("com.android.settings:id/switch_widget")
        x = elm.location['x']
        y = elm.location['y']

        if status == "Off":
                # Enable wifi
                # driver.swipe(961, 87, 989, 92)
            self.driver.swipe(x + 5, y + 10, x + 30, y + 10)


            i=0
            while i<10:
                try:

                    self.driver.find_element_by_xpath("//android.widget.TextView[@text='nqa']")
                except Exception as e:
                    i=i+1
                    print(i, " s waiting for wifi connected now.")
                    time.sleep(1)
                else:
                    print("wifi connected now..")
                    break

            self.assertTrue(self.driver.find_element_by_xpath("//android.widget.TextView[@text='nqa']"))


        else:
                # Disable wifi
                # driver.swipe(989, 92, 961, 87)
            self.driver.swipe(x + 30, y + 10, x + 5, y + 10)

            self.assertEqual(self.test_wifi_a_status(), "Off", "Failed to Disbale wifi!")
            time.sleep(3)

    # @unittest.skip("skip wifi cycle testing.   ")
    def test_wifi_d_cycle_switch(self, counts=20):
        self.counts = counts
        i = 0
        while i < self.counts:
            print("Cycle: ", i)
            self.test_wifi_b_switch()
            i = i + 1

    def test_wifi_c_connect(self):
        status = self.test_wifi_a_status()

        if status == "Off":
            self.test_wifi_b_switch()

        if status =="On":

            i=0
            while i < 10:
                try:
                    self.driver.find_element_by_xpath("//android.widget.TextView[@text='nqa']")
                except Exception as e:
                    i=i+1
                    self.assertNotEqual(i, 10, "Wifi failed to find nqa network.Something should be wrong.")
                    time.sleep(1)
                else:
                    break

            self.driver.find_element_by_xpath("//android.widget.TextView[@text='nqa']").click()

            try:
                self.driver.find_element_by_xpath("//android.widget.Button[@text='FORGET']")

            except Exception as e:
                self.driver.find_element_by_xpath("//android.widget.Button[@text='CANCEL']")

            else:
                self.driver.find_element_by_xpath("//android.widget.Button[@text='FORGET']").click()


            self.driver.find_element_by_xpath("//android.widget.TextView[@text='nqa']").click()
            self.driver.implicitly_wait(3)

            self.driver.find_element_by_id("com.android.settings:id/password").send_keys("9876543201")

            self.driver.find_element_by_id("android:id/button1").click()


            # implicity-wait not suitable here for the status will change into Saved first and then transfer to Connected.
            time.sleep(5)
            result = self.driver.find_element_by_id("android:id/summary").text

            self.assertEqual(result, "Connected", "Connection failed in the case.")

    def test_wifi_e_cycle2(self, times=20):
        self.times = times
        i = 0
        while i < self.times:
            print(i , " times cycle2 operation.")
            self.test_wifi_c_connect()
            self.test_wifi_b_switch()

            self.assertEqual(self.test_wifi_a_status(), "Off", "Cycle2 failed.")
            i = i + 1




#if __name__ == '__main__':
if True:

    suite = unittest.TestLoader().loadTestsFromTestCase(WifiClass)
    unittest.TextTestRunner().run(suite)
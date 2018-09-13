#! /usr/bin/env python3
#coding: utf-8
#Author By Han Wei

import os

def my_path(): return os.path.dirname(os.getcwd())

screenshot_path=my_path() + '/report'
class take_screenshot(object):
    def __init__(self, func):
        self.func = func
        self.name = os.path.join(screenshot_path, func.__name__ + '(__main__.CalTestCase).png')

    def __call__(self, *args):
        try:
            self.func(self, *args)
        finally:
            driver.get_screenshot_as_file()


#! /usr/bin/env python3
#coding: utf-8
#Author By Han Wei

import os
import time

def my_path(): return os.path.dirname(os.getcwd())


report_path = os.path.join(my_path()+'/report')

print(report_path)

rq = time.strftime('%Y%m%d%H%M', time.localtime(time.time()))

report_file = os.path.join(report_path, rq+'.html')

#fp = open(report_file, "wb")

if __name__ =="__main__":
    fp = open(report_file, "wb")






#! /usr/bin/env python3
#encoding: utf-8
#Author By Han Wei


import logging
import os
import time

def my_path(): return os.path.dirname(os.getcwd())


log_path = os.path.join(my_path()+'/log')

rq = time.strftime('%Y%m%d%H%M', time.localtime(time.time()))

log_file = os.path.join(log_path, rq+'.log')


logging.basicConfig(level=logging.INFO,
                    filename=log_file,
                    filemode="a",
                    format='%(asctime)s - %(filename)s[line: %(lineno)d] -%(levelname)s : %(message)s'
                    )

if __name__ =="__main__":
    logging.info("aaa")













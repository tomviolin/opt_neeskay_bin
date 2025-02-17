#!/usr/bin/env python3
from datetime import datetime
import pymysql
import os,sys

def days_between(d1, d2):
    d1 = datetime.strptime(d1, "%Y-%m-%d")
    d2 = datetime.strptime(d2, "%Y-%m-%d")
    return abs((d2 - d1).days)

print (datetime.now())

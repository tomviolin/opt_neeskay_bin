#!/usr/bin/env python3\

import time,sys,json
last = time.clock_gettime_ns(time.CLOCK_MONOTONIC_RAW)
lastline=last
while True:
	line = sys.stdin.readline().replace("'",'"')
	now = time.clock_gettime_ns(time.CLOCK_MONOTONIC_RAW)
	elapsed = now-last
	linetime = now - lastline
	lastline=now
	if line[2:8]=='$GPZDA': last=now
	nmeaid = json.loads(line)[0]
	print (f"{elapsed // 1000000000:02d}.{elapsed%1000000000:09d},{linetime//1000000000:02d}.{linetime%1000000000:09d},\"{nmeaid[1:]}\"",flush=True)


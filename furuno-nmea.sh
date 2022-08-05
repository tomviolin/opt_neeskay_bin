#!/bin/bash
#
#  furuno.sh  - runs the kermit script to collect data from on-board Furuno GPS / depth sounder
#

cd /opt/neeskay/bin
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/
while [ true ]; do
	echo MARK: `date` 2>&1 | tee -a furuno-nmea.log
	./furuno-nmea.py      2>&1 | tee -a furuno-nmea.log
done

#!/bin/bash
#
#  kvh-nmea.sh  - runs the kermit script to collect data from on-board KVH fluxgate compass
#

cd /opt/neeskay/bin

while [ true ]; do
	echo MARK: `date` 2>&1 | tee -a kvh-nmea.log
	./kvh-nmea.ksc      2>&1 | tee -a kvh-nmea.log
done

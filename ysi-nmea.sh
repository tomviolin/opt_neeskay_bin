#!/bin/sh

#  wrapper script for ysi.ksc

# make sure we're in the right directory
cd /opt/neeskay/bin

# start 'er up
./ysi-nmea.ksc

# done- delete PID file and flag file
rm -f /opt/neeskay/run/ysi-nmea.pid
rm -f /opt/neeskay/run/ysicollect-nmea.flg

# also delete current data file
rm -f /opt/neeskay/data/ysi-nmea.csv
rm -f /opt/neeskay/data/ysi-nmea.raw

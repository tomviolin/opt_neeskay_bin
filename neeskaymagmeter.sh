#!/bin/bash
PIDFILE=/var/run/neeskaymagmeter.pid
echo $$ > $PIDFILE
cd /opt/neeskay/bin
python3 compass.py


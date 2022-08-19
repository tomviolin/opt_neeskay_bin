#!/bin/bash
PIDFILE=/tmp/run/neeskaymagmeter.pid
mkdir -p /tmp/run
echo $$ > $PIDFILE
cd /opt/neeskay/bin
python3 neeskaymagmeter.py


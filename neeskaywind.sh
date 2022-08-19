#!/bin/bash
PIDFILE=/tmp/run/neeskaywind.pid
mkdir -p /tmp/run
echo $$ > $PIDFILE
cd /opt/neeskay/bin
python3 neeskaywind.py >/tmp/wind.log 2>&1 


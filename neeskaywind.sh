#!/bin/bash
PIDFILE=/var/run/neeskaywind.pid
echo $$ > $PIDFILE
cd /opt/neeskay/bin
python3 wind.py


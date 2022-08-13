#!/bin/bash

cd /opt/neeskay/bin
./furuno-nmeactl.sh start >/dev/null 2>&1
./neeskaymagmeterctl.sh start >/dev/null 2>&1
# ./neeskaywindctl.sh start >/dev/null 2>&1


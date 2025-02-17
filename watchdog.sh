#!/bin/bash

cd /opt/neeskay/bin

# main Furuno data stream
./furuno-nmeactl.sh start >/dev/null 2>&1


# wind meter data
if [ \! -f /tmp/windran.flag ]; then
	./neeskaywindctl.sh restart >> /tmp/windlog.txt
else
	rm /tmp/windran.flag
fi
./neeskaywindctl.sh start >/tmp/windlog.txt 2>&1


# mag meter (compass) data
#if false; then
#	if [ \! -f /tmp/magmeterran.flag ]; then
#		./neeskaymagmeterctl.sh restart >> /tmp/magmeterlog.txt
#	else
#		rm /tmp/magmeterran.flag
#	fi
#fi


./neeskaymagmeterctl.sh start >>/tmp/magmeterlog.txt 2>&1





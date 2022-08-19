#!/bin/bash

cd /opt/neeskay/bin
#echo "0=$0"
# establish bash name of daemon from command name
#   (command name = (basename)ctl.sh)
daemonbase=`basename "$0" ctl.sh`
#echo "daemonbase=$daemonbase"
# establish search string for pgrep
#   first character is surrounded by brackets to
#   keep the pgrep command from matching itself
daemonsearch="[${daemonbase:0:1}]${daemonbase:1}"
#echo "daemonsearch=$daemonsearch"
# determine status before going in
me=$$
#echo ">>" "pgrep $daemonsearch | grep -v ctl\\\.sh"
daemonprocs=`ps -ef | grep "$daemonsearch" | grep -v ctl.sh | awk '{ print $2 }'`
#echo "daemonprocs=$daemonprocs"
if [ "x$daemonprocs" == "x" ]; then
	dstat=stopped
else
	dstat=running
fi

case "$1" in

	status)
		echo $daemonbase is $dstat.
		;;

	start)
		if [ $dstat = running ]; then
			echo $daemonbase is already $dstat.
		else
			echo starting ${daemonbase}.sh...
			/usr/bin/nohup ./${daemonbase}.sh > /dev/null 2>&1 &
			sleep 1
			$0 status
		fi
		;;

	stop)
		if [ $dstat = stopped ]; then
			echo $daemonbase is already $dstat.
		else
			echo killing ${daemonprocs}...
			kill $daemonprocs
			sleep 3
			$0 status
		fi
		;;

	restart)
		$0 stop
		$0 start
		;;

	*)
		echo usage: $0 '{start|stop|restart|status}'
		;;

esac


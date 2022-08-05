#!/bin/bash
#
#  Script to serve as daemon process to keep
#  the bathymetry charts a-comin'.
#
PATH=/usr/local/bin:$PATH
PIDFILE=/var/lock/bathydaemon.pid
echo $$ > $PIDFILE

# go to the binaries directory
cd /opt/neeskay/bin

# loop 'forever'
while (true); do
	
	# see if we should still be running
	if [ ! -f dobathy.flag ]; then
		# flag file has been removed.
		# stop running if no command line args were passed
		# (any cmd line args override the flag file)
		if [ "x$1" = "x" ]; then
			rm -f $PIDFILE
			exit
		fi
	fi

	# bring the bathymetry database table up-to-date
	./cleanbathy.php

	# preliminary crunch 
	./getbathydata.php 1 1 1 1 10000 neeskay 

	# produce bathymetry plot
	R --no-save < 2dbathym.R
	DIR=`date +%Y-%m-%d`
	FILE=`date +%Y-%m-%d-%H%M%S`
	mkdir -p tl/$DIR
	cp bathy.png tl/$DIR/bathy-$FILE.png

	# is there a cmd line arg of "1"?
	if [ "x$1" = "x1" ]; then
		# yes-- this was a one-shot deal, no iteration
		exit
	fi
done


#!/bin/bash


if [ "x$1" = "x" ]; then
	echo "usage: startdate enddate 'noaa'|'neeskay'|'both' interval"
	exit 1
fi

#establish default dataset
dataset=neeskay

# take first parameter - startdate
startdate=`date "+%Y-%m-%d %H:%M:%S" -d "$1"`
enddate="$startdate"
shift

# take second parameter - enddate
if [ "x$1" != "x" -a "x$1" != "x." ]; then
	enddate=$1
fi

shift

# take third parameter - dataset

if [ "x$1" = "xnoaa" -o "x$1" = "xneeskay" -o "x$1" = "xboth" ]; then
	dataset=$1
	shift
else
	echo "invalid parameter: $1"
	echo "usage: startdate enddate ('noaa'|'neeskay'|'both') interval"
	exit 1
fi

# take fourth parameter - interval

interval=30
if [ "x$1" <> "x" -a "x$1" <> "x." ]; then
	interval=$1
fi

mkdir -p playback
offset=0
while (true); do
	offsetdate=$(date "+%Y-%m-%d %H:%M:%S" -d "$startdate $offset seconds")
	echo === $offsetdate ===
	./getbathydata.php 1 1 1 1 10000 "$dataset" "$offsetdate"
	R --no-save <2dbathym.R
	convert bathy.png -background white -flatten -quality 75 playback/$dataset-`date +%Y-%m%d-%H%M%S -d "$offsetdate"`.jpg
	if [ "$offsetdate" = "$enddate" ]; then
		break
	fi
	offset=$(($offset+$interval))
done

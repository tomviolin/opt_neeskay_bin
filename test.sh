#!/bin/bash
export mastervar=first

( while [ -f test.flag ]; do
	echo mastervar = $mastervar
	sleep 1
  done
) &
sleep 3

mastervar=second

#!/bin/bash

# clean out old kml files
find /var/www/neeskay/gmaps -mtime +2 -name \*.kml -exec rm -f {} \;



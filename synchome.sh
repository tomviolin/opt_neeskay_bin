#!/bin/bash
cd ..
tar -czf tohome.tgz bin/2dbathym.R data/r_proc/* data/bathypos.tab data/bathysifields.csv data/bathycompletetrack.tab /var/www/neeskay/bbox.csv
scp -P23422 tohome.tgz tomhansen.com:neeskay
scp -P31522 tohome.tgz tomh-desk.glwi.uwm.edu:neeskay

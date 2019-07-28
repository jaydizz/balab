#!/bin/bash

for f in *.db; do mv "$f" old/""${f%.db}"_$(date '+%Y_%m_%d').db"; done

wget http://ftp.afrinic.net/pub/dbase/afrinic.db.gz
wget ftp://ftp.arin.net/pub/rr/arin.db
wget ftp://ftp.radb.net/radb/dbase/radb.db.gz
wget ftp://ftp.ripe.net/ripe/dbase/split/ripe.db.route.gz
wget ftp://ftp.ripe.net/ripe/dbase/split/ripe.db.route6.gz


gunzip ./*


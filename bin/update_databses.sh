#!/bin/bash

#
# Update IRR-Stuff
#



cd /mount/storage/db/irr
for f in *.db*; do mv "$f" old/""${f%}"_$(date '+%Y_%m_%d-%h')"; done

wget http://ftp.afrinic.net/pub/dbase/afrinic.db.gz
wget ftp://ftp.arin.net/pub/rr/arin.db
wget ftp://ftp.radb.net/radb/dbase/radb.db.gz
wget ftp://ftp.ripe.net/ripe/dbase/split/ripe.db.route.gz
wget ftp://ftp.ripe.net/ripe/dbase/split/ripe.db.route6.gz
wget ftp://ftp.apnic.net/pub/apnic/whois/apnic.db.route.gz
wget ftp://ftp.apnic.net/pub/apnic/whois/apnic.db.route6.gz

gunzip ./*

cd ../rpki
for f in *; do mv "$f" old/""${f%}"_$(date '+%Y_%m_%d-%h')"; done
routinator vrps > current

pkill --signal USR1 -F /var/run/ris_live.pid


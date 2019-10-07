#!/bin/bash
#
# Script to rsync Cisco configs from Rancid from a remote server
# e.g: rsync ranciduser@rancidserver:~networking/configs/*.cfg /tmp/cisco/
# Author: Edvin Dunaway - edvin@eddinn.net
# Last update: 2019-06-18 # Y-M-D

PATH=/bin:/sbin:/usr/sbin:/usr/bin
RSYNC=$(command -v rsync)
export RSYNC
USER="username"
HOSTNAME="hostname"
RANCIDPATH="/path/to/rancid/config/dir/"
DESTPATH="/path/to/dir/"

[[ -d $DESTPATH ]] || mkdir "$DESTPATH"
"$RSYNC" "$USERNAME"@"$HOSTNAME":"$RANCIDPATH"* "$DESTPATH"
chmod -R 755 $DESTPATH
cd "$DESTPATH" || exit
for i in *.cfg; do
	sed -i 's/\r//g' "$i"
	sed -i 's/<--- More --->              //g' "$i"
done
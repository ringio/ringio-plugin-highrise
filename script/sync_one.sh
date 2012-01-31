#!/bin/sh
SERVICE=synchronize_one_debugging
if ps ax | grep -v grep| grep $SERVICE | grep $1
then
	echo "Sync detected for account $1, new one not starting"
else
	echo "Sync not detected for account $1, we'll go ahead and do that"
	cd /home/ashish/ringio-plugin-highrise && RAILS_ENV=production rake synchronize_one_debugging[$1]
fi

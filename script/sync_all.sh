#!/bin/sh
SERVICE='sync_all_smart'
if ps ax | grep -v grep | grep $SERVICE
then
    echo "$SERVICE service running. We will not start another synchronization"
else
    echo "$SERVICE is not running. It is ok to start another synchronization"

cd /home/ashish/ringio-plugin-highrise && RAILS_ENV=production rake sync_all_smart
fi


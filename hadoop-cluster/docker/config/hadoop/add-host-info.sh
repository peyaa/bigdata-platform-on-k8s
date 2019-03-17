#!/bin/bash
#parameter list:1,IP;2,hostname;
local_host=$(hostname)
local_ip=`/sbin/ifconfig eth0 | sed -nr 's/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`

existing_ip=`cat /etc/hosts | grep $2 | awk '{print $1}'`
node_type=`echo $local_host | grep master-standby`
if [ -n "$node_type" ]; then
    existing_ip=`cat /etc/hosts | grep $2 | grep -v standby | awk '{print $1}'`
fi

if [ -z "$existing_ip" ]; then
    echo "$1 $2" >> /etc/hosts
else
    if [ ! "$existing_ip" = "$1" ]; then
        vi -c :%s/$existing_ip/$1/g -c :wq /etc/hosts  &> /dev/null
    fi
fi

echo "$local_ip $local_host"
#!/bin/bash

local_host=$(hostname)
master_host_name=${local_host%%-standby}
while true
do
    nc -z -w 1 $master_host_name $(( 9020 + $1 ))
    if [ $? -eq 0 ]
    then
        break 2
    fi
done

$HADOOP_HOME/bin/hdfs namenode -bootstrapStandby
$HADOOP_HOME/bin/hdfs namenode &
$HADOOP_HOME/bin/hdfs zkfc &
$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager &

tail -f /dev/null
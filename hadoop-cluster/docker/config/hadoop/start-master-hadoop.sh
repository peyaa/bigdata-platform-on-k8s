#!/bin/bash

i=1
while [ "$i" -le "$1" ]
do
    line=$2-slave$i
    myid=`echo $line | grep -Eo 'slave[0-9]+' | grep -Eo '[0-9]+'`
    zk_port=$(( $myid + 2182 + $3 ))
    nc -z -w 1 $line $zk_port
    if [ $? -eq 0 ]
    then
        jn_port=$(( $myid + 8686 + $3 ))
        nc -z -w 1 $line $jn_port
        if [ $? -eq 0 ]
        then
            break 1
        fi
    fi
done

$HADOOP_HOME/bin/hdfs namenode -format
$HADOOP_HOME/bin/hdfs zkfc -formatZK
$HADOOP_HOME/bin/hdfs namenode &
$HADOOP_HOME/bin/hdfs zkfc &
$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager &

#initiate hive metedata server
$HIVE_HOME/bin/schematool -dbType mysql -initSchema

tail -f /dev/null
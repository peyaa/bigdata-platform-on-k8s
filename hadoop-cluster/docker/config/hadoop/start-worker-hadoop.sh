#!/bin/bash
local_host=$(hostname)
local_ip=`/sbin/ifconfig eth0 | sed -nr 's/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
myid=`echo $local_host | grep -Eo 'slave[0-9]+' | grep -Eo '[0-9]+'`
zk_port=$(( $myid + 2182 + $4 ))
sed -i "s/2181-x/$zk_port/" /tmp/zoo.cfg
i=1
while [ "$i" -le "$2" ]
do
    zk_port1=$(( $i + 2889 + $4 ))
    zk_port2=$(( $i + 3889 + $4 ))
    if [ "$myid" -eq "$i" ]; then
        echo "server.$i=0.0.0.0:$zk_port1:$zk_port2" >> /tmp/zoo.cfg
    else
        echo "server.$i=$3-slave$i:$zk_port1:$zk_port2" >> /tmp/zoo.cfg
    fi
    
    if [ $myid -gt $i ]; then
        res=`cat /etc/hosts | grep $3-slave$i | wc -l`
        if [ $res -eq 0 ]; then
            remote_host=`sshpass -p $1 ssh dn-$3-slave$i '/tmp/add-host-info.sh '$local_ip' '$local_host`
            echo $remote_host >> /etc/hosts
        fi
    fi
    ((i++))
done

#start zookeeper
mkdir $ZOOKEEPER_HOME/zk-data
echo $myid > $ZOOKEEPER_HOME/zk-data/myid
cat /tmp/zoo.cfg > $ZOOKEEPER_HOME/conf/zoo.cfg
zkServer.sh start

#sync journalnode data
if [ ! -d "/opt/hdfs/journalnode/$local_host/$1" ]; then
    i=1
    while [ "$i" -le "$2" ]
    do
        if [ $i -ne $myid ]; then
            sshpass -p $1 scp -r root@$3-slave$i:/opt/hdfs/journalnode/$3-slave$i/* /opt/hdfs/journalnode/$local_host
            if [ -d "/opt/hdfs/journalnode/$local_host/$1" ]; then
                break
            fi
        fi
    ((i++))
    done
fi

$HADOOP_HOME/bin/hdfs journalnode &

master_host_name=$3-master
standby_host_name=$master_host_name-standby

while true
do
    nc -z -w 1 $master_host_name $(( 9020 + $4 ))
    if [ $? -eq 0 ]
    then
        nc -z -w 1 $standby_host_name $(( 9021 + $4 ))
        if [ $? -eq 0 ]
        then
            break 1
        fi
    fi
done

$HADOOP_HOME/bin/hdfs datanode &
$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager &

/tmp/check-slave-status.sh &

tail -f /dev/null
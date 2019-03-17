#!/bin/bash
ReplacStrInFile(){
    sed -i "s/$1/$2/" $3
}

SyncClusterHostsInfo(){
    while true
    do
        nc -zv -w 1 $1 22 2>/dev/null
        if [ $? -eq 0 ]
        then
            remote_host=`sshpass -p $4 ssh $1 '/tmp/add-host-info.sh '$2' '$3`
            echo $remote_host >> /etc/hosts
            break
        fi
    done
}
touch /tmp/healthy
echo root:$1 | chpasswd
ReplacStrInFile "PermitRootLogin without-password" "PermitRootLogin yes" /etc/ssh/sshd_config
service ssh start

dn_prefix=""
local_host=$(hostname)
local_ip=`/sbin/ifconfig eth0 | sed -nr 's/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
echo -e "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n::1         localhost localhost.localdomain localhost6 localhost6.localdomain6\n$local_ip $local_host" > /etc/hosts
myid=0
node_type=`echo $local_host | grep master | grep -v standby`
if [ -n "$node_type" ]; then 
    ReplacStrInFile "{dfs_datanode_address_port}" $(( 50010 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_http_address_port}" $(( 50175 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_https_address_port}" $(( 50475 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_ipc_address_port}" $(( 8810 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_http_address_port}" $(( 8780 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_https_address_port}" $(( 8580 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_rpc_address_port}" $(( 8685 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{yarn_nodemanager_localizer_address_port}" $(( 8040 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
    ReplacStrInFile "{yarn_nodemanager_webapp_address_port}" $(( 8242 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
    SyncClusterHostsInfo dn-$3-master-standby $local_ip $local_host $1
fi

node_type=`echo $local_host | grep master-standby`
if [ -n "$node_type" ]; then
    ReplacStrInFile "{dfs_datanode_address_port}" $(( 50011 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_http_address_port}"  $(( 50176 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_https_address_port}" $(( 50476 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_ipc_address_port}" $(( 8811 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_http_address_port}" $(( 8781 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_https_address_port}" $(( 8581 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_rpc_address_port}" $(( 8686 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{yarn_nodemanager_localizer_address_port}" $(( 8041 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
    ReplacStrInFile "{yarn_nodemanager_webapp_address_port}" $(( 8243 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
fi

node_type=`echo $local_host | grep -Eo 'slave[0-9]+'`
if [ -n "$node_type" ]; then
    myid=`echo $local_host | grep -Eo 'slave[0-9]+' | grep -Eo '[0-9]+'`
    #datanode ports
    ReplacStrInFile "{dfs_datanode_address_port}" $(( $myid + 50011 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_http_address_port}" $(( $myid + 50176 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_https_address_port}" $(( $myid + 50476 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_datanode_ipc_address_port}" $(( $myid + 8811 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_http_address_port}" $(( $myid + 8781 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_https_address_port}" $(( $myid + 8581 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{dfs_journalnode_rpc_address_port}" $(( $myid + 8686 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    ReplacStrInFile "{yarn_nodemanager_localizer_address_port}" $(( $myid + 8041 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
    ReplacStrInFile "{yarn_nodemanager_webapp_address_port}" $(( $myid + 8243 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
    SyncClusterHostsInfo dn-$3-master $local_ip $local_host $1
    SyncClusterHostsInfo dn-$3-master-standby $local_ip $local_host $1
fi

zookeeper_cluster=""
journal_cluster=""
i=1
while [ "$i" -le "$2" ]
do
    zk_port=$(( $i + 2182 + $4 ))
    jn_port=$(( $i + 8686 + $4 ))
    zookeeper_cluster="$zookeeper_cluster$3-slave$i:$zk_port,"
    journal_cluster="$journal_cluster$3-slave$i:$jn_port;"
    if [ $myid -ne 0 ]; then
        if [ $myid -lt $i ]; then
            SyncClusterHostsInfo dn-$3-slave$i $local_ip $local_host $1
        fi
    fi
    ((i++))
done

echo "dataDir=$ZOOKEEPER_HOME/zk-data" >> /tmp/zoo.cfg
zookeeper_cluster=${zookeeper_cluster%?}
journal_cluster=${journal_cluster%?}

mkdir -p /opt/hdfs/journalnode/$local_host /opt/hdfs/tmp/$local_host /opt/hdfs/namenode/$local_host /opt/hdfs/datanode/$local_host

ReplacStrInFile "{node_dir}" $local_host $HADOOP_HOME/etc/hadoop/hdfs-site.xml
ReplacStrInFile "{node_dir}" $local_host $HADOOP_HOME/etc/hadoop/core-site.xml

ReplacStrInFile "{hadoop_ha_cluster_name}" $1 $HADOOP_HOME/etc/hadoop/core-site.xml
ReplacStrInFile "{zookeeper_cluster_url}" $zookeeper_cluster $HADOOP_HOME/etc/hadoop/core-site.xml

ReplacStrInFile "{hadoop_ha_cluster_name}" $1 $HADOOP_HOME/etc/hadoop/hdfs-site.xml
ReplacStrInFile "{journal_node_url}" $journal_cluster $HADOOP_HOME/etc/hadoop/hdfs-site.xml

ReplacStrInFile "{hadoop_ha_cluster_name}" $1 $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{zookeeper_cluster_url}" $zookeeper_cluster $HADOOP_HOME/etc/hadoop/yarn-site.xml

ReplacStrInFile "{hadoop_master_node_host_name}" $3-master $HADOOP_HOME/etc/hadoop/hdfs-site.xml
ReplacStrInFile "{hadoop_master_node_host_name}" $3-master $HADOOP_HOME/etc/hadoop/yarn-site.xml

ReplacStrInFile "{dfs_namenode_http_address_nn1_port}" $(( 50070 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
ReplacStrInFile "{dfs_namenode_http_address_nn2_port}" $(( 50071 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
ReplacStrInFile "{dfs_namenode_rpc_address_nn1_port}" $(( 9020 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
ReplacStrInFile "{dfs_namenode_rpc_address_nn2_port}" $(( 9021 + $4 )) $HADOOP_HOME/etc/hadoop/hdfs-site.xml
ReplacStrInFile "{yarn_resourcemanager_address_rm1_port}" $(( 9132 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_address_rm2_port}" $(( 9133 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_admin_address_rm1_port}" $(( 9233 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_admin_address_rm2_port}" $(( 9234 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_webapp_https_address_rm1_port}" $(( 9390 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_webapp_https_address_rm2_port}" $(( 9391 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_scheduler_address_rm1_port}" $(( 9430 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_scheduler_address_rm2_port}" $(( 9430 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_resource_tracker_address_rm1_port}" $(( 9531 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_resource_tracker_address_rm2_port}" $(( 9531 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_webapp_address_rm1_port}" $(( 9688 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml
ReplacStrInFile "{yarn_resourcemanager_webapp_address_rm2_port}" $(( 9689 + $4 )) $HADOOP_HOME/etc/hadoop/yarn-site.xml

db_port=$(( 3306 + $4 ))
ReplacStrInFile "{database-host}" "dn-$3-metadb-srv" $HIVE_HOME/conf/hive-site.xml
ReplacStrInFile "{database-port}" "$db_port" $HIVE_HOME/conf/hive-site.xml
ReplacStrInFile "{databese-passwd}" "$1" $HIVE_HOME/conf/hive-site.xml
#!/bin/bash

#number of slaves, default is 3
SLAVE_COUNT=${1:-3}
#cluster owner, default is tic
POD_OWNER=${2:-'tic'}
#cluster name default value is default
CLUSTER_NAME=${3:-'default'}
#hadoop version
VERSION=${4:-'2.9.1'}

BASE_DIR=$(cd "$(dirname "$0")"; pwd)
K8S_PODS_BASE_DIR="$BASE_DIR/k8s"
HADOOP_IMG="hadoop-img-$VERSION"
MASTER_WITH_SLAVES="$SLAVE_COUNT-slaves"
K8S_PODS_DIR="$K8S_PODS_BASE_DIR/pods/$HADOOP_IMG/$MASTER_WITH_SLAVES/$POD_OWNER/$CLUSTER_NAME"
HADOOP_IMG="hadoop-img-$VERSION"
CLUSTER_NAME_PREFIX="$MASTER_WITH_SLAVES-$POD_OWNER-$CLUSTER_NAME"
hadoop_master_img="$HADOOP_IMG-master-with-$CLUSTER_NAME_PREFIX"
VERSION_NUMBER=`echo $VERSION | tr -cd "[0-9]"`

#check whehter pods are created, if yes delete them
is_pods_created=`ls $K8S_PODS_DIR/*.yaml 2>/dev/null | wc -l`
if [ $is_pods_created -gt 0 ];then
    kubectl delete -f $K8S_PODS_DIR
    rm -rf $K8S_PODS_DIR
    echo -e "\033[44;37m checking stauts \033[0m"
    while true
    do
        running_pod=`kubectl get pods -o wide -n $POD_OWNER | grep $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER | wc -l`
        if [ "$running_pod" -eq "0" ] 
        then
            break 2
        else
            sleep 5
        fi
    done
    echo -e "\033[44;37m done! the cluster has been destroyed! \033[0m"
else
    echo -e "\033[41;37m can not find cluster! \033[0m"
fi
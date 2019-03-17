#!/bin/bash
set -e

#node type
NODE_TYPE=${1:-'master'}
#number of slaves, default is 3
SLAVE_COUNT=${2:-3}
#cluster owner, default is tic
POD_OWNER=${3:-'tic'}
#cluster name default value is default
CLUSTER_NAME=${4:-'default'}
#hadoop version
VERSION=${5:-'2.9.1'}

MASTER_WITH_SLAVES="$SLAVE_COUNT-slaves"
VERSION_NUMBER=`echo $VERSION | tr -cd "[0-9]"`
CLUSTER_NAME_PREFIX="$MASTER_WITH_SLAVES-$POD_OWNER-$CLUSTER_NAME-hadoop-$VERSION_NUMBER"

POD_NAME=""
case $NODE_TYPE in
master)
    POD_NAME=`kubectl get pods -o wide -n $POD_OWNER | grep $CLUSTER_NAME_PREFIX-master | grep -v standby | grep Running | awk '{ print $1 }'`
    ;;
standby)
    POD_NAME=`kubectl get pods -o wide -n $POD_OWNER | grep $CLUSTER_NAME_PREFIX-master-standby | grep Running | awk '{ print $1 }'`
    ;;
slave*)
    POD_NAME=`kubectl get pods -o wide -n $POD_OWNER | grep $CLUSTER_NAME_PREFIX-$NODE_TYPE | grep Running | awk '{ print $1 }'`
    ;;
*)
    POD_NAME=""
    ;;
esac

if [ -n "$POD_NAME" ]; then
    kubectl exec -it -n $POD_OWNER $POD_NAME -- bash
else
    echo -e "\033[41;37m can't find the pod \033[0m"
    echo -e "\033[41;37m parameters you can input are:node-type(default:master),slave count(default:3), pod owner(default:tic),cluster name((default:default)) \033[0m"
    echo -e "\033[41;37m values of node-type are: master,standby, slaveX(X:sequence number of slave node) \033[0m"
fi
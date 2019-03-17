#!/bin/bash
set -e

#number of slaves, default is 3
SLAVE_COUNT=${1:-3}
#cluster owner, default is tic
POD_OWNER=${2:-'tic'}
#cluster name default value is default
CLUSTER_NAME=${3:-'default'}
#hadoop version
VERSION=${4:-'2.9.1'}

#base variables
BASE_DIR=$(cd "$(dirname "$0")"; pwd)
DOCKER_PRIVATE_SRV_INFO=($(cat $BASE_DIR/docker-image-srv))
DOCKER_IMG_SVR=${DOCKER_PRIVATE_SRV_INFO[0]}

#hadoop cluster variables
HADOOP_IMG="hadoop-img-$VERSION"
MASTER_WITH_SLAVES="$SLAVE_COUNT-slaves"
HADOOP_FILE_NAME="hadoop-$VERSION.tar.gz"
HADOOP_CLUSTER_DIR="$BASE_DIR/hadoop-cluster"
VERSION_NUMBER=`echo $VERSION | tr -cd "[0-9]"`
HADOOP_TARGET_FILE="$HADOOP_CLUSTER_DIR/$HADOOP_FILE_NAME"
CLUSTER_NAME_PREFIX="$MASTER_WITH_SLAVES-$POD_OWNER-$CLUSTER_NAME"
HDFS_CLUSTER_ID=`cat /dev/urandom | head -n 10 | md5sum | head -c 10`


#k8s variables
K8S_PODS_BASE_DIR="$BASE_DIR/k8s"
REGISTRY_KEY="docker-registry-key"
PORTS_OFFSET_FILE="$K8S_PODS_BASE_DIR/ports_offset"
CULSTER_PORT_OFFSET_FILE="$BASE_DIR/cluster_ports_offset"
K8S_PODS_DIR="$K8S_PODS_BASE_DIR/pods/$HADOOP_IMG/$MASTER_WITH_SLAVES/$POD_OWNER/$CLUSTER_NAME"

#zookeeper variables
ZOOKEEPER_VERSION=$(cat $BASE_DIR/zookeeper-version)
ZOOKEEPER_TARGET_FILE_NAME="$HADOOP_CLUSTER_DIR/zookeeper-$ZOOKEEPER_VERSION.tar.gz"

#spark variables
SPARK_VERSION=$(cat $BASE_DIR/spark-version)
SPARK_TARGET_FILE_NAME="$HADOOP_CLUSTER_DIR/spark-$SPARK_VERSION-bin-without-hadoop.tgz"

#scala variables
SCALA_VERSION=$(cat $BASE_DIR/scala-version)
SCALA_TARGET_FILE_NAME="$HADOOP_CLUSTER_DIR/scala-$SCALA_VERSION.tgz"

#hive variables
HIVE_VERSION=$(cat $BASE_DIR/hive-version)
HIVE_TARGET_FILE_NAME="$HADOOP_CLUSTER_DIR/apache-hive-$HIVE_VERSION-bin.tar.gz"

#check exec permission
if [ ! -x "$BASE_DIR/clean-img.sh" ]; then  
    chmod +x $BASE_DIR/clean-img.sh
fi

if [ ! -x "$BASE_DIR/destory-cluster.sh" ]; then  
    chmod +x $BASE_DIR/destory-cluster.sh
fi

if [ ! -x "$BASE_DIR/entry-k8s-pod.sh" ]; then  
    chmod +x $BASE_DIR/entry-k8s-pod.sh
fi 

if [ ! -f "/usr/local/bin/delete_docker_registry_image.py" ]; then
    cp $BASE_DIR/delete_docker_registry_image.py /usr/local/bin/
    chmod +x /usr/local/bin/delete_docker_registry_image.py
fi

#use sed to replace string in a file, tree arguments,1: search string, 2: replacement, 3: file
ReplacStrInFile(){
    sed -i "s/$1/$2/g" $3
}

#function for building image,parameters: 1: hadoop version, 2: image name
BuildClusterImage(){
    ReplacStrInFile "{hadoop-version}" $VERSION $HADOOP_CLUSTER_DIR/docker/Dockerfile
    ReplacStrInFile "{zookeeper-version}" $ZOOKEEPER_VERSION $HADOOP_CLUSTER_DIR/docker/Dockerfile
    ReplacStrInFile "{spark-version}" $SPARK_VERSION $HADOOP_CLUSTER_DIR/docker/Dockerfile
    ReplacStrInFile "{scala-version}" $SCALA_VERSION $HADOOP_CLUSTER_DIR/docker/Dockerfile
    ReplacStrInFile "{hive-version}" $HIVE_VERSION $HADOOP_CLUSTER_DIR/docker/Dockerfile
    cd  $HADOOP_CLUSTER_DIR/docker
    ls | grep -v Dockerfile | grep -v config | xargs rm -rf 
    cp $HADOOP_TARGET_FILE $HADOOP_CLUSTER_DIR/docker
    cp $ZOOKEEPER_TARGET_FILE_NAME $HADOOP_CLUSTER_DIR/docker
    cp $SPARK_TARGET_FILE_NAME $HADOOP_CLUSTER_DIR/docker
    cp $SCALA_TARGET_FILE_NAME $HADOOP_CLUSTER_DIR/docker
    cp $HIVE_TARGET_FILE_NAME $HADOOP_CLUSTER_DIR/docker
    docker build -t $1 .
    docker tag $1 $DOCKER_IMG_SVR/$1
    docker push $DOCKER_IMG_SVR/$1
    ReplacStrInFile $VERSION "{hadoop-version}" $HADOOP_CLUSTER_DIR/docker/Dockerfile
    ReplacStrInFile $ZOOKEEPER_VERSION "{zookeeper-version}" $HADOOP_CLUSTER_DIR/docker/Dockerfile
    ReplacStrInFile $SPARK_VERSION "{spark-version}" $HADOOP_CLUSTER_DIR/docker/Dockerfile
    ReplacStrInFile $SCALA_VERSION "{scala-version}" $HADOOP_CLUSTER_DIR/docker/Dockerfile
    ReplacStrInFile $HIVE_VERSION "{hive-version}" $HADOOP_CLUSTER_DIR/docker/Dockerfile
    cd $BASE_DIR
}

CheckPodRunning(){
    echo -e "\033[44;37m checking $1 status \033[0m"
    while true
    do
        case $1 in
            master)
                running_pod=`kubectl get pods -o wide -n $POD_OWNER | grep $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-master | grep -v standby | grep Running | wc -l`
                ;;
            standby)
                running_pod=`kubectl get pods -o wide -n $POD_OWNER | grep $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-master-standby | grep Running | wc -l`
                ;;
            slave)
                running_pod=`kubectl get pods -o wide -n $POD_OWNER | grep $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-slave | grep Running | wc -l`
                ;;
            svc)
                running_pod=`kubectl get svc --no-headers -n $POD_OWNER | grep dn-$CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER | grep -v metadb-srv | awk '{print $3}' | grep -v none  | wc -l`
                ;;
            metadb-srv)
                running_pod=`kubectl get pods -o wide -n $POD_OWNER | grep $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-metadb-srv | grep Running | wc -l`
                ;;
        esac

        if [ "$running_pod" -eq "$2" ] 
        then
            echo -e "\033[44;37m $1 got Ready! \033[0m"
            break 2
        else
            sleep 1
        fi
    done
}

is_wget_installed=`rpm -qa|grep wget|wc -l`
if [ $is_wget_installed -eq 0 ];then
    sudo yum -y install wget
fi

#download zookeeper
if [ ! -f $ZOOKEEPER_TARGET_FILE_NAME ]; then
    echo -e "\033[44;37m downloading zookeeper-$ZOOKEEPER_VERSION.tar.gz \033[0m"
    wget -P $HADOOP_CLUSTER_DIR https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-$ZOOKEEPER_VERSION/zookeeper-$ZOOKEEPER_VERSION.tar.gz
fi

#download spark
if [ ! -f $SPARK_TARGET_FILE_NAME ]; then
    echo -e "\033[44;37m downloading spark-$SPARK_VERSION.tgz \033[0m"
    wget -P $HADOOP_CLUSTER_DIR  https://mirrors.tuna.tsinghua.edu.cn/apache/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-without-hadoop.tgz
fi

#download scala
if [ ! -f $SCALA_TARGET_FILE_NAME ]; then
    echo -e "\033[44;37m downloading scala-$SCALA_VERSION.tgz \033[0m"
    wget -P $HADOOP_CLUSTER_DIR https://downloads.lightbend.com/scala/$SCALA_VERSION/scala-$SCALA_VERSION.tgz
fi

#download hadoop 
if [ ! -f $HADOOP_TARGET_FILE ]; then
    echo -e "\033[44;37m downloading hadoop-$VERSION.tar.gz \033[0m"
    wget -P $HADOOP_CLUSTER_DIR http://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-$VERSION/hadoop-$VERSION.tar.gz
fi

#download hive 
if [ ! -f $HIVE_TARGET_FILE_NAME ]; then
    echo -e "\033[44;37m downloading apache-hive-$HIVE_VERSION-bin.tar.gz \033[0m"
    wget -P $HADOOP_CLUSTER_DIR https://mirrors.tuna.tsinghua.edu.cn/apache/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz
fi

#if namespace is not created, create
is_namespace_created=`kubectl get namespaces | grep $POD_OWNER | wc -l`
if [ $is_namespace_created -eq 0 ];then
    kubectl create namespace $POD_OWNER
    kubectl create secret docker-registry $REGISTRY_KEY -n $POD_OWNER --docker-server=$DOCKER_IMG_SVR --docker-username=${DOCKER_PRIVATE_SRV_INFO[1]} --docker-password=${DOCKER_PRIVATE_SRV_INFO[2]} --docker-email=${DOCKER_PRIVATE_SRV_INFO[3]}
fi

#check whehter pods are created, if yes delete them
is_pods_created=`ls $K8S_PODS_DIR/*.yaml 2>/dev/null | wc -l`
if [ $is_pods_created -gt 0 ];then
    $BASE_DIR/destory-cluster.sh $SLAVE_COUNT $POD_OWNER $CLUSTER_NAME $VERSION 
fi

#check whether base image  is running, if no then build it
is_base_img_created=`docker image list | grep k8s/bigdatabaseimg | wc -l`
if [ $is_base_img_created -eq 0 ];then
    cd  $BASE_DIR/baseimg
    docker build -t k8s/bigdatabaseimg .
    cd $BASE_DIR
fi

#slave image
is_hadoop_img_created=`docker image list | grep $HADOOP_IMG | wc -l`
if [ $is_hadoop_img_created -eq 0 ];then
    BuildClusterImage $HADOOP_IMG
fi

cluster_ports_offset=0
if [ -f $CULSTER_PORT_OFFSET_FILE ]; then
    cluster_ports_offset=`cat $CULSTER_PORT_OFFSET_FILE`
    cluster_ports_offset=$(($cluster_ports_offset+1))
fi
echo $(($cluster_ports_offset+$SLAVE_COUNT-1)) > $CULSTER_PORT_OFFSET_FILE

# pods on k8s
mkdir -p $K8S_PODS_DIR

#create metadata server
cp $BASE_DIR/k8s/template/mysql-metadata-srv.yaml $K8S_PODS_DIR/mysql-metadata-srv.yaml 
ReplacStrInFile "{cluster-metadb-config}" "$CLUSTER_NAME_PREFIX-$VERSION_NUMBER-metadb-config" $K8S_PODS_DIR/mysql-metadata-srv.yaml 
ReplacStrInFile "{cluster_namespace}" $POD_OWNER $K8S_PODS_DIR/mysql-metadata-srv.yaml 
db_port=$(( 3306 + $cluster_ports_offset ))
ReplacStrInFile "{cluster-metadb-listen-port}" $db_port $K8S_PODS_DIR/mysql-metadata-srv.yaml 
ReplacStrInFile "{cluster_metadb_host_name}" "$CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-metadb-srv" $K8S_PODS_DIR/mysql-metadata-srv.yaml
ReplacStrInFile "{docker_img_srv_url}" $DOCKER_IMG_SVR  $K8S_PODS_DIR/mysql-metadata-srv.yaml
ReplacStrInFile "{mysql-root-pwd}" $HDFS_CLUSTER_ID $K8S_PODS_DIR/mysql-metadata-srv.yaml
kubectl create -f $K8S_PODS_DIR/mysql-metadata-srv.yaml
CheckPodRunning "metadb-srv" 1


i=1
while [ "$i" -le "$SLAVE_COUNT" ]
do
    if [ ! -f $K8S_PODS_DIR/hadoop-cluster-dn-slave$i.yaml ]; then
        cp $BASE_DIR/k8s/template/hadoop-cluster-dn-slave.yaml $K8S_PODS_DIR/hadoop-cluster-dn-slave$i.yaml
        ReplacStrInFile "{cluster_namespace}" $POD_OWNER $K8S_PODS_DIR/hadoop-cluster-dn-slave$i.yaml
        ReplacStrInFile "{cluster_slave_node_host_name}" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-slave$i $K8S_PODS_DIR/hadoop-cluster-dn-slave$i.yaml
        kubectl create -f $K8S_PODS_DIR/hadoop-cluster-dn-slave$i.yaml
    fi
    ((i++))
done

if [ ! -f $K8S_PODS_DIR/hadoop-cluster-dn-master.yaml ]; then
    cp $BASE_DIR/k8s/template/hadoop-cluster-dn-master.yaml $K8S_PODS_DIR/hadoop-cluster-dn-master.yaml
    ReplacStrInFile "{cluster_master_node_host_name}" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-master $K8S_PODS_DIR/hadoop-cluster-dn-master.yaml
    ReplacStrInFile "{cluster_namespace}" $POD_OWNER $K8S_PODS_DIR/hadoop-cluster-dn-master.yaml
    kubectl create -f $K8S_PODS_DIR/hadoop-cluster-dn-master.yaml
fi

if [ ! -f $K8S_PODS_DIR/hadoop-cluster-dn-master-standby.yaml ]; then
    cp $BASE_DIR/k8s/template/hadoop-cluster-dn-master-standby.yaml $K8S_PODS_DIR/hadoop-cluster-dn-master-standby.yaml
    ReplacStrInFile "{cluster_namespace}" $POD_OWNER $K8S_PODS_DIR/hadoop-cluster-dn-master-standby.yaml
    ReplacStrInFile "{cluster_master_node_host_name}" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-master $K8S_PODS_DIR/hadoop-cluster-dn-master-standby.yaml
    kubectl create -f $K8S_PODS_DIR/hadoop-cluster-dn-master-standby.yaml
fi

svc_count=$(( $SLAVE_COUNT + 2 ))
CheckPodRunning "svc" $svc_count

i=1
while [ "$i" -le "$SLAVE_COUNT" ]
do
    cp $BASE_DIR/k8s/template/hadoop-cluster-slave.yaml $K8S_PODS_DIR/hadoop-slave$i.yaml
    
    ReplacStrInFile "{docker_img_name}" $HADOOP_IMG $K8S_PODS_DIR/hadoop-slave$i.yaml
    ReplacStrInFile "{cluster_slave_node_host_name}" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-slave$i $K8S_PODS_DIR/hadoop-slave$i.yaml
    ReplacStrInFile "{cluster_namespace}" $POD_OWNER $K8S_PODS_DIR/hadoop-slave$i.yaml
    ReplacStrInFile "{docker_img_srv_url}" $DOCKER_IMG_SVR $K8S_PODS_DIR/hadoop-slave$i.yaml
    ReplacStrInFile "cluster-id" $HDFS_CLUSTER_ID $K8S_PODS_DIR/hadoop-slave$i.yaml
    ReplacStrInFile "slave-count" $SLAVE_COUNT $K8S_PODS_DIR/hadoop-slave$i.yaml
    ReplacStrInFile "cluster-prefix" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER $K8S_PODS_DIR/hadoop-slave$i.yaml
    ReplacStrInFile "cluster-port-offset" $cluster_ports_offset $K8S_PODS_DIR/hadoop-slave$i.yaml

    zk_port=$(( $i + 2182 + $cluster_ports_offset ))
    jn_port=$(( $i + 8686 + $cluster_ports_offset ))
    zk_port1=$(( $i + 2889 + $cluster_ports_offset ))
    zk_port2=$(( $i + 3889 + $cluster_ports_offset ))
    echo  "            - containerPort: $zk_port" >> $K8S_PODS_DIR/hadoop-slave$i.yaml
    echo  "            - containerPort: $jn_port" >> $K8S_PODS_DIR/hadoop-slave$i.yaml
    echo  "            - containerPort: $zk_port1" >> $K8S_PODS_DIR/hadoop-slave$i.yaml
    echo  "            - containerPort: $zk_port2" >> $K8S_PODS_DIR/hadoop-slave$i.yaml
    kubectl create -f $K8S_PODS_DIR/hadoop-slave$i.yaml
    ((i++))
done

CheckPodRunning "slave" $SLAVE_COUNT

#change hadoop docker image version
cp $BASE_DIR/k8s/template/hadoop-cluster-master.yaml $K8S_PODS_DIR/hadoop-cluster-master.yaml
cp $BASE_DIR/k8s/template/hadoop-cluster-master-standby.yaml $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "{cluster_namespace}" $POD_OWNER $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "{cluster_namespace}" $POD_OWNER $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "{docker_img_name}" $HADOOP_IMG $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "{docker_img_name}" $HADOOP_IMG $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "{cluster_master_node_host_name}" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-master $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "{cluster_master_node_host_name}" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER-master $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "{master_node_nodeport_svc}" $POD_OWNER-$CLUSTER_NAME-$MASTER_WITH_SLAVES-$VERSION_NUMBER-svc $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "{master_node_nodeport_svc}" $POD_OWNER-$CLUSTER_NAME-$MASTER_WITH_SLAVES-$VERSION_NUMBER-svc $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "{docker_img_srv_url}" $DOCKER_IMG_SVR $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "{docker_img_srv_url}" $DOCKER_IMG_SVR $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "cluster-id" $HDFS_CLUSTER_ID $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "cluster-id" $HDFS_CLUSTER_ID $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "slave-count" $SLAVE_COUNT $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "slave-count" $SLAVE_COUNT $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "cluster-prefix" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "cluster-prefix" $CLUSTER_NAME_PREFIX-hadoop-$VERSION_NUMBER $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "cluster-port-offset" $cluster_ports_offset $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "cluster-port-offset" $cluster_ports_offset $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ReplacStrInFile "{master_namenode_msgr_port}" $(( 50070 + $cluster_ports_offset )) $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "{master_resource_msgr_port}" $(( 9688 + $cluster_ports_offset )) $K8S_PODS_DIR/hadoop-cluster-master.yaml

ReplacStrInFile "{standby_namenode_msgr_port}" $(( 50071 + $cluster_ports_offset )) $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml
ReplacStrInFile "{standby_resource_msgr_port}" $(( 9689 + $cluster_ports_offset )) $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

ports_offset=0
if [ ! -f $PORTS_OFFSET_FILE ]; then
    echo "0" > $PORTS_OFFSET_FILE
else
    ports_offset=`cat $PORTS_OFFSET_FILE`
    ports_offset=$(( $ports_offset + 1 ))
    echo $ports_offset > $PORTS_OFFSET_FILE
fi

#master node ports
ports_offset_30000=$(( $ports_offset + 30000 ))
ports_offset_30100=$(( $ports_offset + 30100 ))
ReplacStrInFile "{master_namenode_msgr_nodeport}" $ports_offset_30000 $K8S_PODS_DIR/hadoop-cluster-master.yaml
ReplacStrInFile "{master_resource_msgr_nodeport}" $ports_offset_30100 $K8S_PODS_DIR/hadoop-cluster-master.yaml

#standby node ports
ports_offset_31000=$(( $ports_offset + 31000 ))
ports_offset_31100=$(( $ports_offset + 31100 ))
ReplacStrInFile "{standby_namenode_msgr_nodeport}" $ports_offset_31000 $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml
ReplacStrInFile "{standby_resource_msgr_nodeport}" $ports_offset_31100 $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml

#create master and standby node
kubectl create -f $K8S_PODS_DIR/hadoop-cluster-master.yaml
CheckPodRunning "master" 1

kubectl create -f $K8S_PODS_DIR/hadoop-cluster-master-standby.yaml
CheckPodRunning "standby" 1

echo -e "\033[44;37m done! the cluster has been created! \033[0m"
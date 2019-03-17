FROM k8s/bigdatabaseimg

WORKDIR /root

ENV VERSION={hadoop-version} \
    ZOOKEEPER_VERSION={zookeeper-version} \
    SPARK_VERSION={spark-version} \
    SCALA_VERSION={scala-version} \
    HIVE_VERSION={hive-version} \
    ZOOKEEPER_HOME=/usr/local/zookeeper-{zookeeper-version} \
    HADOOP_HOME=/usr/local/hadoop-{hadoop-version} \
    SPARK_HOME=/usr/local/spark-{spark-version}-bin-without-hadoop \
    SCALA_HOME=/usr/local/scala-{scala-version} \
    HIVE_HOME=/usr/local/apache-hive-{hive-version}-bin


ADD hadoop-$VERSION.tar.gz zookeeper-$ZOOKEEPER_VERSION.tar.gz spark-$SPARK_VERSION-bin-without-hadoop.tgz scala-$SCALA_VERSION.tgz apache-hive-$HIVE_VERSION-bin.tar.gz /usr/local/

ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop \
    YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop \
    HIVE_CONF_DIR=$HIVE_HOME/conf \
    ZOOBINDIR=$ZOOKEEPER_HOME/bin \
    ZOO_LOG_DIR=$ZOOKEEPER_HOME/logs \
    PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$SPARK_HOME/bin:$SPARK_HOME/sbin:$SCALA_HOME/bin:$HIVE_HOME/bin

COPY config/hadoop/* config/zookeeper/* config/spark/* config/hive/* config/db/* /tmp/

RUN mkdir -p $HADOOP_HOME/logs /root/.ssh $HIVE_HOME/tmp /opt $ZOOKEEPER_HOME/logs && \
    mv /tmp/ssh_config /root/.ssh/config && \
    mv /tmp/hadoop-env.sh $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    mv /tmp/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml && \ 
    mv /tmp/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml && \
    mv /tmp/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml && \
    mv /tmp/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml && \
    mv /tmp/capacity-scheduler.xml $HADOOP_HOME/etc/hadoop/capacity-scheduler.xml && \
    mv /tmp/spark-env.sh $SPARK_HOME/conf/spark-env.sh && \
    mv /tmp/hive-site.xml $HIVE_HOME/conf/hive-site.xml && \
    ln -s /tmp/mysql-connector-java.jar $HIVE_HOME/lib/mysql-connector-java.jar && \
    chmod +x /tmp/start-master-hadoop.sh && \
    chmod +x /tmp/check-slave-status.sh && \
    chmod +x /tmp/start-worker-hadoop.sh && \
    chmod +x /tmp/init-cluster-config.sh && \
    chmod +x /tmp/add-host-info.sh && \
    chmod +x $HADOOP_HOME/sbin/start-dfs.sh && \
    chmod +x $HADOOP_HOME/sbin/start-yarn.sh && \
    chmod +x $HADOOP_HOME/sbin/yarn-daemon.sh
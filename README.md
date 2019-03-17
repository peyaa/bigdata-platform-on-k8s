## ***Dependencies***

- Docker: 17.03.2-ce +
- Kubernets: 1.11.2 +
- User: Root 
- OS: CentOS 7+
- Docker private repository with access control, login credentials should be stored in file [docker-image-srv] including       docker private repository url, user name, user password, email separated by white space.
-  mariadb docker image (latest)

## ***CLI Instructions***

### Command

/path/to/hadoop-cluster-on-docker/make-hadoop-cluster-on-k8s.sh slaves-count cluster-owner cluster-name hadoop-version

### Command Parameter list

| Parameter Name | Memo                                                 |
| -------------- | ---------------------------------------------------- |
| slaves-count   | slave node count of hadoop cluster, default value: 3 |
| cluster-owner  | cluster owner, default value: tic                    |
| cluster-name   | Cluster name, default vale:default                   |
| hadoop-version | Hadoop binary tarball version, default value:2.9.1   |



## ***Components***

| Component Name | Default Version | Version conf file         | Download URL                                              |
| -------------- | --------------- | ----------------- | --------------------------------------------------------- |
| Hadoop         | 2.9.1           | -              | http://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/ |
| Spark          | 2.3.2           | spark-version     | https://mirrors.tuna.tsinghua.edu.cn/apache/spark/        |
| Hive           | 2.3.4           | hive-version      | https://mirrors.tuna.tsinghua.edu.cn/apache/hive          |
| Zookeeper      | 3.4.13          | zookeeper-version | https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper     |
| Scala          | 2.12.7          | scala-version     | https://downloads.lightbend.com/scala                     |


#!/bin/bash
BASE_DIR=$(cd "$(dirname "$0")"; pwd)
DOCKER_PRIVATE_SRV_INFO=($(cat $BASE_DIR/docker-image-srv))
DOCKER_IMG_SVR=${DOCKER_PRIVATE_SRV_INFO[0]}

IMG_NAME=${1:-"hadoop-img-2.9.1"}
docker rmi $IMG_NAME $DOCKER_IMG_SVR/$IMG_NAME -f
/usr/local/bin/delete_docker_registry_image.py -i $IMG_NAME
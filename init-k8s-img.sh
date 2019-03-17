#!/bin/bash
init-img()
{
  docker pull $1$2
  docker tag $1$2 $3$2
  docker rmi $1$2
}

for img in $* ; do
  init-img "anjia0532/google-containers." "$img" "k8s.gcr.io/"
done
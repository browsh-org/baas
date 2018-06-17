#!/bin/bash

docker run \
  --restart=always \
  -v $PWD/etc:/etc/browsh \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $PWD/.docker-machine:/home/user/.docker/machine \
  -p 80:80 \
  -p 22:22 \
  -p 60000-60100:60000-60100/udp \
  -e GCLOUD_PROJECT_ID \
  baas-master

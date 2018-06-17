#!/bin/bash
set -e

chown -R root:docker /var/run/docker.sock
service nginx start
browsh-ssh-server 2>&1 | gcloud_logger "browsh-ssh-server" &
su user -c 'swarm-manager.sh 2>&1 | gcloud_logger "browsh-swarm-manager"'

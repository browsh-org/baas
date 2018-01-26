#!/bin/bash

DEFAULTS_FILE=/etc/browsh-swarm-defaults.conf
DEFAULT_OS_IMAGE=https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-9-stretch-v20180105
DEFAULT_ZONE=us-east1-b
NODE_PREFIX="browshswarmnode"
count=0

maintain_swarm () {
  get_defaults
  get_swarm_state
  if [ $node_count -eq 0 ];
  then
    create_swarm
  elif [ $node_count -lt $node_count_target ];
  then
    add_node
  fi
}

get_defaults () {
  source $DEFAULTS_FILE
  memory=$(expr $memory \* 1024)
  machine_type="custom-$cpus-$memory"
}

get_swarm_state () {
  machines=$(docker-machine ls --filter="state=Running" --format "{{.Name}}")
  node_count=$(echo $machines | grep -o $NODE_PREFIX | wc -l)
}

# Update the Browsh docker image to the specified tag
pull_browsh_docker_image () {
  # Connect to each machine?
  docker pull browsh-org/browsh
}


node_command() {
  echo "Running '$2' on $1 ..."
  last_ssh_output=$(docker-machine ssh $1 "$2")
}

# Start a fresh Swarm from nothing.
# Generates the Swarm discovery token and the leader's IP address
create_swarm () {
  echo "Attempting to create a new swarm..."
  create_node
  init_swarm
}

init_swarm() {
  echo "Initialising swarm..."
  ip=$(docker-machine ip $last_built_machine)
  _init_swarm="docker swarm init --advertise-addr $ip"
  node_command $last_built_machine "$_init_swarm"
}

# We need to do this everytime, because we're using short-lived VMs, so there's
# no guarantee of any single IP address or token.
get_join_credentials() {
  echo "Getting swarm join credentials..."
  a_manager_node=$(echo $machines | head -n1 | cut -d " " -f1)
  a_manager_ip=$(docker-machine ip $a_manager_node)
  _get_token="docker swarm join-token manager --quiet"
  node_command $a_manager_node "$_get_token"
  swarm_token=$last_ssh_output
}

node_join_swarm() {
  get_join_credentials
  _command="docker swarm join --token $swarm_token $a_manager_ip:2377"
  node_command $last_built_machine "$_command"
}

create_node () {
  echo "Creating a new swarm node VM..."
  _random=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6 ; echo '')
  count=$(expr $count + 1)
  name="$NODE_PREFIX$_random$count"
  docker-machine create --driver google \
    --engine-storage-driver overlay2 \
    --google-project browsh-193210 \
    --google-zone $DEFAULT_ZONE \
    --google-machine-type $machine_type \
    --google-tags swarm-node \
    --google-machine-image $DEFAULT_OS_IMAGE \
    --google-preemptible \
    $name
  last_built_machine=$name
  post_create
}

post_create() {
  # Might be a bug that we need to do this
  node_command $last_built_machine "sudo usermod -aG docker docker-user"
}

add_node() {
  create_node
  node_join_swarm
}

daemonise () {
  echo "Starting Browsh Swarm Manager as a daemon..."
  while true
  do
    maintain_swarm
    sleep 5
  done
}

if [ "$1"=="-once" ]
then
  echo "Running maintenance one time only..."
  maintain_swarm
else
  daemonise
fi


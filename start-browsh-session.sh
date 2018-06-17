#!/bin/bash
set -e
source $HOME/.bashrc
DEFAULTS_FILE=/etc/browsh/swarm-defaults.conf
source $DEFAULTS_FILE
BROWSH_URL=${BROWSH_URL:-https://www.brow.sh/ssh-welcome}

echo "Welcome to brow.sh ($browsh_version)"

IFS=',' read -r -a browsh_users <<< "$users"

if [[ " ${browsh_users[@]} " =~ " ${BROWSH_USER} " ]]; then
  echo "Hello $BROWSH_USER, starting your anonymous, unlimited session..."
  command="/home/user/browsh -startup-url $BROWSH_URL"
else
  echo "Starting your public session, which will only last 5 minutes and be logged."
  command="
    touch ./debug.log && tail -f ./debug.log | gcloud_logger 'browsh-session' & \
    /home/user/browsh \
      -startup-url $BROWSH_URL \
      -time-limit 300 \
      -debug
  "
fi

echo "Startup URL: $BROWSH_URL"
echo "Please wait..."

random=$(( ( RANDOM % $node_target_count )  + 1 ))
_nodes=$(docker-machine ls --filter="state=Running" --format "{{.Name}}")
a_manager_node=$(echo $_nodes | head -n1 | cut -d " " -f$random)
eval $(docker-machine env $a_manager_node)

docker run \
  --rm \
  -it \
  -e GCLOUD_PROJECT_ID \
  tombh/texttop:$browsh_version \
  bash -c "$command"

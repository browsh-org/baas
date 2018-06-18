#!/bin/bash
set -e

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


#!/bin/bash
set -e

BROWSH_URL=${BROWSH_URL:-https://www.brow.sh/ssh-welcome}

browsh_version=$(cat .browsh_version)

echo "Welcome to brow.sh ($browsh_version)"

IFS=',' read -r -a browsh_users <<< "$BROWSH_USERS"

if [[ " ${browsh_users[@]} " =~ " ${SSH_USER} " ]]; then
  echo "Hello $SSH_USER, starting your unlogged and unlimited session..."
  command="/app/browsh -startup-url $BROWSH_URL"
else
  echo "Starting your public session, which will only last 5 minutes and be logged."
  command="
    /app/browsh \
      -startup-url $BROWSH_URL \
      -time-limit 300 \
      -debug
  "
fi

echo "Startup URL: $BROWSH_URL"
echo "Please wait..."

eval $command

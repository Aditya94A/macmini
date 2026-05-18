#!/bin/bash
set -e
REMOTE=adi@192.168.1.218
REMOTE_DIR=~/projects/frigate

rsync -avz "$(dirname "$0")/" "$REMOTE:$REMOTE_DIR/"
ssh "$REMOTE" "
  eval \"\$(/opt/homebrew/bin/brew shellenv)\"
  export DOCKER_HOST='unix:///Users/adi/.colima/default/docker.sock'
  cd $REMOTE_DIR
  docker compose pull
  docker compose up -d
  docker ps --filter name=frigate --format 'frigate: {{.Status}}'
"
echo "Done. UI → http://192.168.1.218:5000"

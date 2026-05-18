#!/bin/bash
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
eval "$(/opt/homebrew/bin/brew shellenv)"
export DOCKER_HOST='unix:///Users/adi/.colima/default/docker.sock'

LOG=/tmp/start-services.log
echo "$(date): starting services" >> $LOG

# Start AdGuard Home on port 53 BEFORE Colima (so it wins the port 53 race)
if ! pgrep -f 'AdGuardHome -s run' > /dev/null; then
  SUDO_ASKPASS=~/.adg_helper.sh sudo -A nohup /Applications/AdGuardHome/AdGuardHome -s run >> $LOG 2>&1 &
  sleep 5
  echo "$(date): AdGuard started" >> $LOG
fi

# Start FrigateDetector (CoreML / M4 Neural Engine) -- optional
DETECTOR_DIR=~/Applications/FrigateDetector.app/Contents/Resources/app
if [ -d "$DETECTOR_DIR" ] && ! pgrep -f zmq_onnx_client > /dev/null; then
  nohup "$DETECTOR_DIR/venv/bin/python3" "$DETECTOR_DIR/detector/zmq_onnx_client.py" --model AUTO >> $LOG 2>&1 &
  sleep 3
  echo "$(date): FrigateDetector started" >> $LOG
fi

# Start Colima (Docker runtime)
colima start -f >> $LOG 2>&1

# Wait for Docker socket
for i in $(seq 1 30); do
  docker ps > /dev/null 2>&1 && break
  sleep 2
done

# Start Frigate
cd ~/projects/frigate
docker compose up -d >> $LOG 2>&1
echo "$(date): Frigate started" >> $LOG

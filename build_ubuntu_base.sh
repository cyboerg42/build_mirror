#!/bin/bash
sudo su
apt-get update
apt-get upgrade -y
./init.sh
cd scripts
./newest_sources.sh ubuntu-1804-server.manifest
cd ../scripts/
screen -d -m -S build "./build.sh"
screen -m -S build_log "tail -f -n100 /tmp/build.log"


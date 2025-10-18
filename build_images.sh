#!/usr/bin/env bash

set -e

# Uncomment lines below if munge is not installed and key not yet generated and copied to the working folder

apt -y install munge

/sbin/mungekey
cp /etc/munge/munge.key ./munge.key

cp /sys/devices/system/cpu/cpu0/topology/thread_siblings ./topo/thread_siblings
cp /sys/devices/system/cpu/cpu0/topology/core_siblings ./topo/core_siblings

docker compose build base
docker compose build
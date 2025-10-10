#!/usr/bin/env bash

set -e

# Uncomment lines below if munge is not installed and key not yet generated and copied to the working folder

apt -y install munge

/sbin/mungekey
cp /etc/munge/munge.key ./munge.key

docker compose build base
docker compose build

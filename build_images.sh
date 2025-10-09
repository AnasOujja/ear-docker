#!/usr/bin/env bash

set -e

# Comment lines below if munge is installed and key already generated and copied to the working folder

apt -y install munge

/sbin/mungekey
cp /etc/munge/munge.key ./munge.key

docker compose build base
docker compose build

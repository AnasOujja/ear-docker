#!/usr/bin/env bash

set -e

yum -y install munge

#/sbin/mungekey
#cp /etc/munge/munge.key ./munge.key

docker compose build base
docker compose build

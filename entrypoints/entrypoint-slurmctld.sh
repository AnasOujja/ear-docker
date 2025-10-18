#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/common-wait.sh

echo "---> Starting MUNGE ..."
gosu munge /usr/sbin/munged

wait_for_tcp slurmdbd 6819 "slurmdbd"

sleep 10
/usr/bin/sacctmgr -i --immediate add cluster name=linux

echo "---> Starting slurmctld ..."
if /usr/sbin/slurmctld -V | grep -q '17.02' ; then
  exec gosu slurm /usr/sbin/slurmctld -Dvvv
else
  exec gosu slurm /usr/sbin/slurmctld -i -Dvvv
fi
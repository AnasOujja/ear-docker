#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/common-wait.sh

echo "---> Starting MUNGE ..."
gosu munge /usr/sbin/munged

wait_for_tcp slurmdbd 6819 "slurmdbd"

sleep 10
/usr/bin/sacctmgr -i --immediate add cluster name=linux

#DB server connection for EAR commands (Not necessary to wait here since slurmdbd waited already for mysql)
#wait_for_tcp mysql 3306 "MariaDB"

echo "---> Starting slurmctld ..."
if /usr/sbin/slurmctld -V | grep -q '17.02' ; then
  exec gosu slurm /usr/sbin/slurmctld -Dvvv
else
  exec gosu slurm /usr/sbin/slurmctld -i -Dvvv
fi


#Connection to compute nodes essential for econtrol command
wait_for_tcp c1 5000 "Compute_Node_1"
wait_for_tcp c2 5000 "Compute_Node_2"
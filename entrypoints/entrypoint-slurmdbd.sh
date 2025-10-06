#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/common-wait.sh

echo "---> Starting MUNGE ..."
gosu munge /usr/sbin/munged

wait_for_tcp mysql 3306 "MariaDB"

echo "---> Checking availability of Slurm_Accounting_DB ..."
. /etc/slurm/slurmdbd.conf
until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
do
  echo "-- Slurm_Accounting_DB not created yet, checking again ..."
  sleep 2
done
echo "-- Slurm_Accounting_DB ready for use"

echo "---> Starting slurmdbd ..."
exec gosu slurm /usr/sbin/slurmdbd -Dvvv
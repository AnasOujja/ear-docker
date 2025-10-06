#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/common-wait.sh

wait_for_tcp mysql 3306 "MariaDB"

echo "---> Checking availability of EAR_DB ..."
. /etc/ear/ear.conf
until echo "SELECT 1" | mysql -h $MariaDBHost -u$MariaDBUser -p$MariaDBPassw 2>&1 > /dev/nul1
do
  echo "-- EAR_DB not created yet, checking again ..."
  sleep 2
done
echo "-- EAR_DB ready for use"

wait_for_tcp c1 5000 "Compute_Node_1"
wait_for_tcp c2 5000 "Compute_Node_2"
echo "---> Starting EARGMD ..."
gosu ear /usr/sbin/eargmd -v
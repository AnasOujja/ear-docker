#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/common-wait.sh

wait_for_tcp mysql 3306 "MariaDB"

echo "---> Checking availability of EAR_DB ..."
. /etc/ear/ear/ear.conf
until echo "SELECT 1" | mysql -h $MariaDBHost -u$MariaDBUser -p$MariaDBPassw 2>&1 > /dev/nul1
do
  echo "-- EAR_DB not created yet, checking again ..."
  sleep 2
done
echo "-- EAR_DB ready for use"

echo "---> Starting EARDBD ..."
gosu ear /usr/sbin/eardbd
#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/common-wait.sh

echo "---> Starting MUNGE ..."
gosu munge /usr/sbin/munged

wait_for_tcp slurmctld 6817 "slurmctld"
wait_for_tcp eardbd 4711 "eardbd"

echo "---> Starting slurmd ..."
exec /usr/sbin/slurmd -Dvvv

#echo "---> Dummy coefficients ..."
#exec /bin/tools/coeffs_null

#echo "---> Starting eard ..."
#exec /usr/sbin/eard -Dvvv
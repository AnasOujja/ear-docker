#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/common-wait.sh

echo "---> Starting MUNGE ..."
gosu munge /usr/sbin/munged

wait_for_tcp slurmctld 6817 "slurmctld"
wait_for_tcp eardbd 4711 "eardbd"

echo "---> Compute Dummy coefficients ..."
cd /etc/ear/coeffs/
/usr/bin/tools/coeffs_null default 3800000 1900000

echo "---> Starting slurmd ..."
/usr/sbin/slurmd -Dvvv

#echo "---> Starting eard ..."
#/usr/sbin/eard -Dvvv
#!/usr/bin/env bash
set -euo pipefail
source /usr/local/bin/common-wait.sh

wait_for_tcp c1 5000 "Compute_Node_1"
wait_for_tcp c2 5000 "Compute_Node_2"

echo "---> Starting EARGMD ..."
gosu ear /usr/sbin/eargmd -v
#!/bin/bash
# ram_bound.sh
# RAM-bound workload: heavy memory bandwidth usage, minimal CPU work.

SIZE_MB=${1:-1024}   # default: 1024 MB = 1 GB
FILE=/dev/shm/ramtest.bin

echo "Creating ${SIZE_MB}MB test file in RAM (${FILE})..."
dd if=/dev/zero of="$FILE" bs=1M count="$SIZE_MB" status=none

echo "Starting RAM-bound read loop over $FILE (Ctrl+C to stop)..."
while true; do
    dd if="$FILE" of=/dev/null bs=1M status=none
done
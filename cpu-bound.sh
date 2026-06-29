#!/bin/bash

N=$1
sum=0

echo "N = $N"

for ((i=0; i<=N; i++)); do
        sum=$((sum + i))
done
echo "$sum"

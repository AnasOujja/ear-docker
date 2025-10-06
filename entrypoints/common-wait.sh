#!/usr/bin/env bash
set -euo pipefail

wait_for_tcp() {
  local host="$1" port="$2" label="${3:-service}"
  echo "Waiting for ${label} at ${host}:${port} ..."
  until (echo > /dev/tcp/"${host}"/"${port}") >/dev/null 2>&1; do
    sleep 1
  done
  echo "${label} is up (${host}:${port})."
}
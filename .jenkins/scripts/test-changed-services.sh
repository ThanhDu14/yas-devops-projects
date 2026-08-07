#!/usr/bin/env bash
set -euo pipefail

CHANGED_SERVICES="${1:-}"

if [ -z "${CHANGED_SERVICES}" ]; then
    echo "No Changed service"
    exit 0  
fi

for SERVICE in ${CHANGED_SERVICES}; do
    echo "Running test for" ${SERVICE}
    mvn -B -pl "${SERVICE}" -am verify
done 

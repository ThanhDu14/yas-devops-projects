#!/usr/bin/env bash
set -euo pipefail

CHANGED_SERVICES="${1:-}"

if [ -z "${CHANGED_SERVICES}" ]; then
    echo "No changed service to build."
    exit 0  
fi

SERVICE_LIST=$(echo "${CHANGED_SERVICES}" | tr ' ' ',')

echo "Building packages in parallel for: ${SERVICE_LIST}"

mvn -B -pl "${SERVICE_LIST}" -am package -DskipTests -T 1C

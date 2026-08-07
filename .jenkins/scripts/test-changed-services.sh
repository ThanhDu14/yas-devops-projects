#!/usr/bin/env bash
set -euo pipefail

CHANGED_SERVICES="${1:-}"
RUN_INTEGRATION_TESTS="${2:-false}"

if [ -z "${CHANGED_SERVICES}" ]; then
    echo "No changed service to test."
    exit 0  
fi

# Chuyển danh sách service từ dạng "service1 service2" sang "service1,service2"
SERVICE_LIST=$(echo "${CHANGED_SERVICES}" | tr ' ' ',')

if [ "${RUN_INTEGRATION_TESTS}" = "true" ]; then
    echo "Running Unit + Integration Tests (mvn verify) in parallel for: ${SERVICE_LIST}"
    mvn -B -pl "${SERVICE_LIST}" -am verify -T 1C -Delasticsearch.url=host.docker.internal
else
    echo "Running Unit Tests (mvn test) in parallel for: ${SERVICE_LIST}"
    mvn -B -pl "${SERVICE_LIST}" -am test -T 1C -DskipITs
fi



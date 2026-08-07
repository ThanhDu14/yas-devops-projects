#!/usr/bin/env bash
set -euo pipefail

CHANGED_SERVICES="${1:-}"

if [ -z "${CHANGED_SERVICES}" ]; then
    echo "No changed service to test."
    exit 0  
fi

# Chuyển danh sách service từ dạng "service1 service2" sang "service1,service2"
SERVICE_LIST=$(echo "${CHANGED_SERVICES}" | tr ' ' ',')

echo "Running tests in parallel for: ${SERVICE_LIST}"

# -T 1C: Tự động chạy song song 1 thread per CPU Core
# test: Chỉ chạy Unit Test (siêu nhanh), không bật Testcontainers nặng nề
mvn -B -pl "${SERVICE_LIST}" -am test -T 1C

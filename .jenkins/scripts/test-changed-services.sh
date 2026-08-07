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

echo "=== Cleaning up stale test containers ==="
docker rm -f $(docker ps -aq --filter "ancestor=docker.elastic.co/elasticsearch/elasticsearch:8.11.3") 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "ancestor=docker.elastic.co/elasticsearch/elasticsearch:9.2.3") 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "publish=9200") 2>/dev/null || true
echo "=== Done cleanup ==="

echo "=== Checking Docker Images on Host ==="
docker images | grep -E "elasticsearch|kafka|keycloak" || true
echo "=== Checking running containers ==="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true
echo "======================================"

if [ "${RUN_INTEGRATION_TESTS}" = "true" ]; then
    echo "Running Unit + Integration Tests (mvn verify) in parallel for: ${SERVICE_LIST}"
    mvn -B -pl "${SERVICE_LIST}" -am verify -T 1C \
        -Delasticsearch.url=host.docker.internal \
        -Dspring.elasticsearch.uris=http://host.docker.internal:9200 \
        -Delasticsearch.version=8.11.3
else
    echo "Running Unit Tests (mvn test) in parallel for: ${SERVICE_LIST}"
    mvn -B -pl "${SERVICE_LIST}" -am test -T 1C -DskipITs \
        -Delasticsearch.url=host.docker.internal \
        -Dspring.elasticsearch.uris=http://host.docker.internal:9200 \
        -Delasticsearch.version=8.11.3
fi



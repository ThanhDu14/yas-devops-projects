
#!/usr/bin/env bash
set -euo pipefail

CHANGED_SERVICES="${1:-}"
RUN_INTEGRATION_TESTS="${2:-false}"

if [ -z "${CHANGED_SERVICES}" ]; then
    echo "No changed service to test."
    exit 0
fi

# Chuyển danh sách service từ dạng "service1 service2"
# sang "service1,service2" để truyền cho Maven -pl
SERVICE_LIST=$(echo "${CHANGED_SERVICES}" | tr ' ' ',')


echo "=== Cleaning up stale Elasticsearch test containers ==="

docker rm -f $(
    docker ps -aq \
        --filter "ancestor=docker.elastic.co/elasticsearch/elasticsearch:8.11.3"
) 2>/dev/null || true

docker rm -f $(
    docker ps -aq \
        --filter "ancestor=docker.elastic.co/elasticsearch/elasticsearch:9.2.3"
) 2>/dev/null || true

echo "=== Done cleanup ==="

echo "=== Checking Docker Images on Host ==="
docker images | grep -E "elasticsearch|kafka|keycloak" || true

echo "=== Checking Running Containers ==="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true

echo "======================================"

if [ "${RUN_INTEGRATION_TESTS}" = "true" ]; then

    echo "=== Elasticsearch containers BEFORE tests ==="

    docker ps -a \
        --filter "ancestor=docker.elastic.co/elasticsearch/elasticsearch:8.11.3" \
        --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"

    echo "Running Unit + Integration Tests (mvn clean verify) for: ${SERVICE_LIST}"

    mvn clean verify -B \
        -pl "${SERVICE_LIST}" \
        -am \
        -Delasticsearch.url=host.docker.internal \
        -Delasticsearch.version=9.2.3

else

    echo "Running Unit Tests only (mvn clean test jacoco:report -DskipITs) for: ${SERVICE_LIST}"

    mvn clean test jacoco:report -B \
        -pl "${SERVICE_LIST}" \
        -am \
        -DskipITs \
        -Delasticsearch.url=host.docker.internal \
        -Delasticsearch.version=9.2.3

fi
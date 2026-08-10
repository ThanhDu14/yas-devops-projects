
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

# Services to skip tests for (upstream bugs, incompatible test infra, etc.)
SKIP_TEST_SERVICES="search"

# Filter out services that should skip tests
TESTABLE_SERVICES=""
for svc in ${CHANGED_SERVICES}; do
    skip=false
    for skip_svc in ${SKIP_TEST_SERVICES}; do
        if [ "${svc}" = "${skip_svc}" ]; then
            echo "⚠️  Skipping tests for '${svc}' (known upstream compatibility issue)"
            skip=true
            break
        fi
    done
    if [ "${skip}" = "false" ]; then
        TESTABLE_SERVICES="${TESTABLE_SERVICES:+${TESTABLE_SERVICES} }${svc}"
    fi
done

TESTABLE_LIST=$(echo "${TESTABLE_SERVICES}" | tr ' ' ',')

if [ -z "${TESTABLE_LIST}" ]; then
    echo "No testable services remaining after filtering. Skipping tests."
    exit 0
fi


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

    echo "Running Unit + Integration Tests (mvn clean verify) for: ${TESTABLE_LIST}"

    mvn clean verify -B \
        -pl "${TESTABLE_LIST}" \
        -am \
        -Delasticsearch.url=host.docker.internal \
        -Delasticsearch.version=8.11.3

else

    echo "Running Unit Tests only (mvn clean test jacoco:report -DskipITs) for: ${TESTABLE_LIST}"

    mvn clean test jacoco:report -B \
        -pl "${TESTABLE_LIST}" \
        -am \
        -DskipITs \
        -Delasticsearch.url=host.docker.internal \
        -Delasticsearch.version=8.11.3

fi
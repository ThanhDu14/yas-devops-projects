#!/usr/bin/env bash
set -euo pipefail

if [ -n "${TARGET_SERVICES:-}" ]; then
    echo "${TARGET_SERVICES}"
    exit 0
fi

SERVICES=(
    common-library backoffice-bff cart customer delivery inventory location 
    media order payment payment-paypal product promotion
    rating recommendation sampledata search storefront-bff tax webhook
)

if [ -n "${CHANGE_TARGET:-}" ]; 
then 
    git fetch origin "${CHANGE_TARGET}" > /dev/null 2>&1
    CHANGED_FILES=$(git diff --name-only "origin/${CHANGE_TARGET}...HEAD")
elif git rev-parse HEAD~1 > /dev/null 2>&1; then
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
else 
    CHANGED_FILES=$(git ls-files)
fi

if printf '%s\n' "${CHANGED_FILES}" | grep -Eq '^(pom.xml|common-library/|Jenkinsfile|.jenkins/)'; then
    echo "${SERVICES[*]}"   
    exit 0
fi

RESULT=()

for SERVICE in "${SERVICES[@]}"; do
    if printf '%s\n' "${CHANGED_FILES}" | grep -q "^${SERVICE}/"; then
      RESULT+=("${SERVICE}")
    fi
done

echo "${RESULT[*]}"
#!/bin/bash
set -e

# ==========================================
# Script: Build & Push Docker Images lên Google Artifact Registry (GAR)
# Sử dụng: ./push-images.sh "product order cart"
# Yêu cầu biến môi trường: GAR_REPO, GCP_REGION
# ==========================================

CHANGED_SERVICES="$1"
GAR_REPO="${GAR_REPO:?❌ Biến GAR_REPO chưa được cấu hình! Ví dụ: asia-southeast1-docker.pkg.dev/PROJECT_ID/yas-docker-repo}"
GCP_REGION="${GCP_REGION:-asia-southeast1}"
BUILD_TAG="${BUILD_NUMBER:-latest}"

if [ -z "$CHANGED_SERVICES" ]; then
  echo "⚠️  Không có service nào thay đổi. Bỏ qua bước push image."
  exit 0
fi

# Xác thực Docker với Google Artifact Registry
echo "🔐 Đăng nhập vào Google Artifact Registry..."
gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet

for SERVICE in $CHANGED_SERVICES; do
  # Bỏ qua các service Frontend (đã chạy trên Cloud Storage)
  if [ "$SERVICE" = "storefront" ] || [ "$SERVICE" = "backoffice" ]; then
    echo "⏭️  Bỏ qua $SERVICE (Frontend chạy trên Cloud Storage, không cần Docker Image)"
    continue
  fi

  # Xác định tên image
  IMAGE_NAME="yas-${SERVICE}"

  # Xử lý trường hợp đặc biệt: storefront-bff và backoffice-bff
  DOCKER_CONTEXT="$SERVICE"
  if [ "$SERVICE" = "storefront-bff" ]; then
    IMAGE_NAME="yas-storefront-bff"
    DOCKER_CONTEXT="storefront-bff"
  elif [ "$SERVICE" = "backoffice-bff" ]; then
    IMAGE_NAME="yas-backoffice-bff"
    DOCKER_CONTEXT="backoffice-bff"
  fi

  # Kiểm tra Dockerfile tồn tại
  if [ ! -f "$DOCKER_CONTEXT/Dockerfile" ]; then
    echo "⚠️  Không tìm thấy Dockerfile cho $SERVICE. Bỏ qua."
    continue
  fi

  FULL_IMAGE="${GAR_REPO}/${IMAGE_NAME}"

  echo "========================================"
  echo "🐳 Building: ${IMAGE_NAME}"
  echo "========================================"

  # Build Docker Image
  TAG_ARGS=(-t "${FULL_IMAGE}:${BUILD_TAG}" -t "${FULL_IMAGE}:latest")
  if [ -n "${GIT_COMMIT_SHORT:-}" ]; then
    TAG_ARGS+=(-t "${FULL_IMAGE}:${GIT_COMMIT_SHORT}")
  fi

  docker build "${TAG_ARGS[@]}" "$DOCKER_CONTEXT"

  # Push lên GAR
  echo "🚀 Pushing: ${FULL_IMAGE}:${BUILD_TAG}"
  docker push "${FULL_IMAGE}:${BUILD_TAG}"
  docker push "${FULL_IMAGE}:latest"
  if [ -n "${GIT_COMMIT_SHORT:-}" ]; then
    docker push "${FULL_IMAGE}:${GIT_COMMIT_SHORT}"
  fi

  echo "✅ Hoàn thành: ${IMAGE_NAME}"
done

echo ""
echo "🎉 Tất cả images đã được push lên GAR thành công!"

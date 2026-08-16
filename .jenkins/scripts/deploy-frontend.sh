#!/bin/bash
set -e

# ==========================================
# Script: Build Frontend Next.js → Deploy lên Google Cloud Storage
# Yêu cầu biến môi trường: GCS_BUCKET_NAME
# ==========================================

CHANGED_SERVICES="$1"
BUCKET_NAME="${GCS_BUCKET_NAME:?❌ Biến GCS_BUCKET_NAME chưa được cấu hình! Ví dụ: yas-front-end-PROJECT_ID}"

deploy_frontend() {
  local APP_DIR="$1"
  local APP_NAME="$2"

  echo "========================================"
  echo "🏗️  Building ${APP_NAME}..."
  echo "========================================"

  cd "$APP_DIR"
  npm ci --production=false
  npm run build

  # Next.js với output: 'export' sẽ tạo thư mục 'out/'
  # Next.js với output: 'standalone' cần thêm bước export
  if [ -d "out" ]; then
    BUILD_DIR="out"
  elif [ -d ".next/static" ]; then
    # Fallback: copy static assets
    BUILD_DIR=".next"
  else
    echo "❌ Không tìm thấy thư mục build output cho ${APP_NAME}"
    exit 1
  fi

  echo "🚀 Uploading ${APP_NAME} to gs://${BUCKET_NAME}/${APP_NAME}/..."
  gcloud storage rsync -r "${BUILD_DIR}/" "gs://${BUCKET_NAME}/${APP_NAME}/" --delete-unmatched-destination-objects

  echo "✅ ${APP_NAME} đã deploy thành công lên Cloud Storage!"
  cd -
}

# Kiểm tra xem Frontend có thay đổi không
if echo "$CHANGED_SERVICES" | grep -qw "storefront"; then
  deploy_frontend "storefront" "storefront"
fi

if echo "$CHANGED_SERVICES" | grep -qw "backoffice"; then
  deploy_frontend "backoffice" "backoffice"
fi

echo "🎉 Frontend deployment hoàn tất!"

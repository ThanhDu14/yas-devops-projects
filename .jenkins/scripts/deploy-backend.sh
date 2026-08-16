#!/bin/bash
set -e

# ==========================================
# Script: Deploy Backend lên VM trong MIG qua Google IAP
# Yêu cầu biến môi trường: GCP_PROJECT_ID, GCP_REGION
# Tuỳ chọn: GCP_ZONE, MIG_NAME, GAR_REPO
# ==========================================

PROJECT_ID="${GCP_PROJECT_ID:?❌ Biến GCP_PROJECT_ID chưa được cấu hình!}"
REGION="${GCP_REGION:-asia-southeast1}"
ZONE="${GCP_ZONE:-${REGION}-a}"
MIG_NAME="${MIG_NAME:-yas-mig}"
GAR_REGISTRY="${GCP_REGION:-asia-southeast1}-docker.pkg.dev"

echo "========================================"
echo "🔍 Tìm danh sách VM đang chạy trong MIG..."
echo "========================================"

# Lấy danh sách tất cả VM đang chạy trong MIG
INSTANCES=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(instance)" 2>/dev/null)

if [ -z "$INSTANCES" ]; then
  echo "❌ Không tìm thấy VM nào đang chạy trong MIG: $MIG_NAME"
  exit 1
fi

echo "📋 Các VM cần cập nhật:"
echo "$INSTANCES"
echo ""

for INSTANCE in $INSTANCES; do
  # Lấy zone thực tế của VM
  INSTANCE_ZONE=$(gcloud compute instances list \
    --filter="name=$INSTANCE" \
    --format="value(zone)" \
    --project="$PROJECT_ID" 2>/dev/null)

  echo "========================================"
  echo "🚀 Đang deploy lên VM: $INSTANCE (Zone: $INSTANCE_ZONE)"
  echo "========================================"

  # SSH vào VM qua IAP và chạy lệnh cập nhật containers
  gcloud compute ssh "$INSTANCE" \
    --zone="$INSTANCE_ZONE" \
    --project="$PROJECT_ID" \
    --tunnel-through-iap \
    --command="
      cd /opt/yas &&
      echo '🔐 Đăng nhập GAR...' &&
      gcloud auth configure-docker ${GAR_REGISTRY} --quiet &&
      echo '⬇️  Kéo Docker Images mới nhất...' &&
      docker compose --env-file .env.prod -f docker-compose.prod.yml pull &&
      echo '🔄 Khởi động lại các containers...' &&
      docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --remove-orphans &&
      echo '🧹 Dọn dẹp images cũ...' &&
      docker image prune -f &&
      echo '✅ Deploy thành công trên \$(hostname)!'
    "

  echo "✅ VM $INSTANCE đã được cập nhật!"
  echo ""
done

echo "🎉 Tất cả VM trong MIG đã deploy xong!"

#!/bin/bash
set -e

# ==========================================
# Script: Deploy Backend lên VM trong MIG qua Google IAP
# Yêu cầu biến môi trường: GCP_PROJECT_ID, GCP_REGION
# ==========================================

PROJECT_ID="${GCP_PROJECT_ID:?Bien GCP_PROJECT_ID chua duoc cau hinh}"
REGION="${GCP_REGION:-asia-southeast1}"
MIG_NAME="${MIG_NAME:-yas-mig}"
GAR_REGISTRY="${GCP_REGION:-asia-southeast1}-docker.pkg.dev"

echo "========================================"
echo "Tim danh sach VM dang chay trong MIG..."
echo "========================================"

# Lấy danh sách tất cả VM đang chạy trong MIG
INSTANCES=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(instance)" 2>/dev/null)

if [ -z "$INSTANCES" ]; then
  echo "Khong tim thay VM nao dang chay trong MIG: $MIG_NAME"
  exit 1
fi

echo "Cac VM can cap nhat:"
echo "$INSTANCES"
echo ""

for INSTANCE in $INSTANCES; do
  # Lấy zone thực tế của VM
  INSTANCE_ZONE=$(gcloud compute instances list \
    --filter="name=$INSTANCE" \
    --format="value(zone)" \
    --project="$PROJECT_ID" 2>/dev/null)

  echo "========================================"
  echo "Dang deploy len VM: $INSTANCE (Zone: $INSTANCE_ZONE)"
  echo "========================================"

  # SSH vào VM qua IAP và chạy lệnh cập nhật
  gcloud compute ssh "$INSTANCE" \
    --zone="$INSTANCE_ZONE" \
    --project="$PROJECT_ID" \
    --tunnel-through-iap \
    --command="
      cd /opt/yas &&
      echo 'Pulling latest code...' &&
      sudo git pull origin ci-media-only-test &&
      echo 'Pulling Docker Images...' &&
      sudo docker compose -f docker-compose.prod.yml pull &&
      echo 'Restarting containers...' &&
      sudo docker compose -f docker-compose.prod.yml up -d --remove-orphans &&
      echo 'Cleaning up old images...' &&
      sudo docker image prune -f &&
      echo 'Deploy thanh cong!'
    "

  echo "VM $INSTANCE da duoc cap nhat!"
  echo ""
done

echo "Tat ca VM trong MIG da deploy xong!"

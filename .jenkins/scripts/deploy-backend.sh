#!/bin/bash
set -e

# ==========================================
# Script: Deploy Backend lên VM trong MIG qua Google IAP
# ==========================================

PROJECT_ID="${GCP_PROJECT_ID:?Bien GCP_PROJECT_ID chua duoc cau hinh}"
REGION="${GCP_REGION:-asia-southeast1}"
MIG_NAME="${MIG_NAME:-yas-mig}"

echo "========================================"
echo "Tim danh sach VM dang chay trong MIG ($MIG_NAME)..."
echo "========================================"

# Lấy danh sách VM và Zone từ MIG theo chuẩn CSV (NAME,ZONE)
VM_LIST=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="csv[no-heading](NAME,ZONE)" 2>/dev/null)

if [ -z "$VM_LIST" ]; then
  echo "Khong tim thay VM nao dang chay trong MIG: $MIG_NAME"
  exit 1
fi

echo "Danh sach VM can cap nhat:"
echo "$VM_LIST"
echo ""

echo "$VM_LIST" | while IFS=',' read -r INSTANCE INSTANCE_ZONE; do
  # Xóa khoảng trắng thừa nếu có
  INSTANCE=$(echo "$INSTANCE" | tr -d '[:space:]')
  INSTANCE_ZONE=$(echo "$INSTANCE_ZONE" | tr -d '[:space:]')

  if [ -z "$INSTANCE" ]; then
    continue
  fi

  echo "========================================"
  echo "Dang deploy len VM: $INSTANCE (Zone: $INSTANCE_ZONE)"
  echo "========================================"

  # SSH vào VM qua IAP với cờ --quiet (tránh hỏi interactive prompt)
  gcloud compute ssh "$INSTANCE" \
    --zone="$INSTANCE_ZONE" \
    --project="$PROJECT_ID" \
    --tunnel-through-iap \
    --quiet \
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
      echo 'Deploy thanh cong tren \$(hostname)!'
    "

  echo "VM $INSTANCE da duoc cap nhat!"
  echo ""
done

echo "Tat ca VM trong MIG da deploy xong!"

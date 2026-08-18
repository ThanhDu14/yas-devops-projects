#!/bin/bash
set -e

# ==========================================
# Script: Deploy Backend lên VM trong MIG qua Google IAP
# ==========================================

PROJECT_ID="${GCP_PROJECT_ID:?Bien GCP_PROJECT_ID chua duoc cau hinh}"
REGION="${GCP_REGION:-asia-southeast1}"
MIG_NAME="${MIG_NAME:-yas-mig}"
GAR_REPO="${GAR_REPO:-${REGION}-docker.pkg.dev/${PROJECT_ID}/yas-docker-repo}"

# Tự động lấy tên nhánh từ Jenkins (hoặc default là main) và làm sạch prefix
RAW_BRANCH="${TARGET_BRANCH:-${BRANCH_NAME:-${GIT_BRANCH:-main}}}"
DEPLOY_BRANCH=$(echo "$RAW_BRANCH" | sed -e 's#^origin/##' -e 's#^refs/heads/##')

echo "========================================"
echo "Thong tin Deploy:"
echo " - Project ID : $PROJECT_ID"
echo " - Region     : $REGION"
echo " - MIG Name   : $MIG_NAME"
echo " - Branch     : $DEPLOY_BRANCH"
echo " - GAR Repo   : $GAR_REPO"
echo "========================================"

echo "Tim danh sach VM dang chay trong MIG ($MIG_NAME)..."

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

  # SSH vào VM qua IAP với cờ --quiet và bỏ qua StrictHostKeyChecking cho môi trường CI/CD
  rm -f /var/jenkins_home/.ssh/google_compute_known_hosts 2>/dev/null || true
  gcloud compute ssh "$INSTANCE" \
    --zone="$INSTANCE_ZONE" \
    --project="$PROJECT_ID" \
    --tunnel-through-iap \
    --quiet \
    --ssh-flag="-o StrictHostKeyChecking=no" \
    --ssh-flag="-o UserKnownHostsFile=/dev/null" \
    --command="
      sudo git config --system --add safe.directory /opt/yas &&
      cd /opt/yas &&
      echo '🔄 Fetching code and checkout branch: $DEPLOY_BRANCH...' &&
      sudo git fetch origin &&
      (sudo git checkout $DEPLOY_BRANCH 2>/dev/null || sudo git checkout -b $DEPLOY_BRANCH origin/$DEPLOY_BRANCH 2>/dev/null || true) &&
      sudo git pull origin $DEPLOY_BRANCH || sudo git pull origin main || true &&
      echo '🔐 Authenticating Docker with GAR on VM...' &&
      gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet 2>/dev/null || true &&
      echo '🐳 Pulling Docker Images from GAR ($GAR_REPO)...' &&
      sudo IMAGE_REGISTRY=${GAR_REPO} COMPOSE_FILE=docker-compose.yml docker compose pull &&
      echo '🚀 Restarting containers...' &&
      sudo IMAGE_REGISTRY=${GAR_REPO} COMPOSE_FILE=docker-compose.yml docker compose up -d --remove-orphans &&
      echo '🧹 Cleaning up old images...' &&
      sudo docker image prune -f &&
      echo \"🎉 Deploy thanh cong tren \$(hostname)!\"
    "

  echo "VM $INSTANCE da duoc cap nhat!"
  echo ""
done

echo "Tat ca VM trong MIG da deploy xong!"

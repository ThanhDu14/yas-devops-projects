#!/bin/bash 
set -e 

# ==========================================
# Startup Script: Tự động cài đặt Docker + Clone + Khởi chạy dự án
# ==========================================

# 1. Cập nhật hệ thống và cài công cụ cần thiết
apt-get update
apt-get install -y ca-certificates curl gnupg git lsb-release 

# 2. Thêm GPG key chính thức của Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 3. Thêm kho lưu trữ Docker vào APT
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker ubuntu 2>/dev/null || true

# 5. Clone repo vào /opt/yas (nếu chưa có)
if [ ! -d "/opt/yas" ]; then
  echo "Cloning YAS repository..."
  git clone -b ci-media-only-test https://github.com/ThanhDu14/yas-devops-projects.git /opt/yas
  chown -R ubuntu:ubuntu /opt/yas
else
  echo "YAS repository already exists, pulling latest..."
  cd /opt/yas && git pull origin ci-media-only-test || true
fi

# 6. Tạo docker network
docker network create yas-network || true

# 7. Xác thực Docker với Google Artifact Registry
gcloud auth configure-docker asia-southeast1-docker.pkg.dev --quiet 2>/dev/null || true

# 8. Tự động khởi động toàn bộ hệ thống bằng image công khai
cd /opt/yas
docker compose -f docker-compose.yml up -d

echo "✅ Startup script completed successfully!"
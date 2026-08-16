#!/bin/bash 
set -e 

# ==========================================
# Startup Script: Tu dong cai dat Docker + Clone + Khoi chay du an
# ==========================================

# 1. Cap nhat he thong va cai cong cu can thiet
apt-get update
apt-get install -y ca-certificates curl gnupg git lsb-release 

# 2. Them GPG key chinh thuc cua Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 3. Them kho luu tru Docker vao APT
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker ubuntu 2>/dev/null || true

# 5. Clone repo vao /opt/yas (neu chua co)
if [ ! -d "/opt/yas" ]; then
  echo "Cloning YAS repository..."
  git clone -b ci-media-only-test https://github.com/ThanhDu14/yas-devops-projects.git /opt/yas
  chown -R ubuntu:ubuntu /opt/yas
else
  echo "YAS repository already exists, pulling latest..."
  cd /opt/yas && git pull origin ci-media-only-test || true
fi

# 6. Tao docker network
docker network create yas-network || true

# 7. Tu dong khoi dong toan bo he thong bang docker-compose.prod.yml
cd /opt/yas
docker compose -f docker-compose.prod.yml up -d

echo "Startup script completed successfully!"
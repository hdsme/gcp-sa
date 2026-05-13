#!/bin/bash

# 1. Định nghĩa thông số
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-c"
INSTANCE_NAME="lamp-1-vm"
MACHINE_TYPE="e2-medium"

# Tìm kiếm Image mới nhất của LAMP stack từ project bitnami-launchpad (phổ biến trên Marketplace)
# hoặc sử dụng debian chuẩn nếu không tìm thấy image marketplace cụ thể.
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"

echo "--- Bắt đầu triển khai hạ tầng ---"

# 2. Kích hoạt API cần thiết
echo "Đang kiểm tra và kích hoạt APIs..."
gcloud services enable compute.googleapis.com deploymentmanager.googleapis.com --quiet

# 3. Kiểm tra Instance tồn tại (Tính Idempotent)
if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE > /dev/null 2>&1; then
    echo "Instance $INSTANCE_NAME đã tồn tại. Bỏ qua bước tạo."
else
    echo "Đang tạo Instance $INSTANCE_NAME..."
    # Sử dụng ảnh debian-11 (ổn định nhất cho LAMP tự build) 
    # Nếu bài lab bắt buộc dùng Marketplace Image, bạn cần chọn Image bằng tay trong Console 
    # và lấy 'Image ID' thay thế vào đây.
    gcloud compute instances create $INSTANCE_NAME \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --network-interface=network-tier=PREMIUM,subnet=default \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --tags=http-server,https-server \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image-family=$IMAGE_FAMILY,image-project=$IMAGE_PROJECT,mode=rw,size=10,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring \
        --reservation-affinity=any
fi

# 4. Kiểm tra Firewall (Tính Idempotent)
if ! gcloud compute firewall-rules describe default-allow-http > /dev/null 2>&1; then
    echo "Đang tạo Firewall Rule cho port 80..."
    gcloud compute firewall-rules create default-allow-http \
        --direction=INGRESS \
        --priority=1000 \
        --network=default \
        --action=ALLOW \
        --rules=tcp:80 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=http-server
else
    echo "Firewall rule đã tồn tại."
fi

# 5. Lấy IP ngoại vi để kiểm tra
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].externalIp)')

echo "--- Hoàn thành ---"
echo "IP của bạn: http://$EXTERNAL_IP"
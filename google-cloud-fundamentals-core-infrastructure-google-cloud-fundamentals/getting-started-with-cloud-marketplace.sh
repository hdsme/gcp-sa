#!/bin/bash

# Thiết lập các biến môi trường từ lab
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-c"
INSTANCE_NAME="lamp-1-vm"
MACHINE_TYPE="e2-medium"

echo "--- Bắt đầu triển khai LAMP Stack ---"

# 1. Kiểm tra và Enable các API cần thiết
echo "Kiểm tra APIs..."
SERVICES=("deploymentmanager.googleapis.com" "compute.googleapis.com" "osconfig.googleapis.com")
for SERVICE in "${SERVICES[@]}"; do
    if ! gcloud services list --enabled --filter="name:$SERVICE" | grep -q "$SERVICE"; then
        echo "Đang kích hoạt $SERVICE..."
        gcloud services enable "$SERVICE"
    else
        echo "$SERVICE đã được kích hoạt."
    fi
done

# 2. Kiểm tra Instance đã tồn tại chưa (Tính Idempotent)
if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE > /dev/null 2>&1; then
    echo "Instance $INSTANCE_NAME đã tồn tại. Bỏ qua bước tạo mới."
else
    echo "Đang triển khai LAMP Stack instance..."
    # LƯU Ý: Marketplace thường sử dụng Deployment Manager. 
    # Ở mức độ script cơ bản, chúng ta tạo instance với cấu hình tương đương LAMP Click-to-Deploy.
    gcloud compute instances create $INSTANCE_NAME \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --network-interface=network-tier=PREMIUM,subnet=default \
        --maintenance-policy=MIGRATE \
        --tags=http-server,https-server \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/click-to-deploy-images/global/images/family/lampstack,mode=rw,size=10,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring \
        --reservation-affinity=any

    # 3. Mở firewall port 80 (HTTP) nếu chưa có
    if ! gcloud compute firewall-rules describe default-allow-http > /dev/null 2>&1; then
        echo "Đang tạo quy tắc firewall cho HTTP..."
        gcloud compute firewall-rules create default-allow-http \
            --direction=INGRESS \
            --priority=1000 \
            --network=default \
            --action=ALLOW \
            --rules=tcp:80 \
            --source-ranges=0.0.0.0/0 \
            --target-tags=http-server
    fi
fi

# 4. Xác minh trạng thái
echo "--- Thông tin triển khai ---"
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].externalIp)')
echo "LAMP Stack đang chạy tại: http://$EXTERNAL_IP"
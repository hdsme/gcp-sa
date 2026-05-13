#!/bin/bash

# Thiết lập các biến môi trường từ Lab
export PROJECT_ID=$(gcloud config get-value project)
export REGION="asia-south1"
export ZONE="asia-south1-a"

# Cấu hình mặc định
gcloud config set compute/zone $ZONE

echo "--- Task 2: Creating a private cluster ---"

# Kiểm tra nếu cluster 1 đã tồn tại
if gcloud container clusters describe private-cluster --zone=$ZONE >/dev/null 2>&1; then
    echo "Cluster private-cluster đã tồn tại."
else
    gcloud beta container clusters create private-cluster \
        --enable-private-nodes \
        --master-ipv4-cidr 172.16.0.16/28 \
        --enable-ip-alias \
        --create-subnetwork "" \
        --machine-type e2-medium \
        --quiet
fi

echo "--- Task 4: Enable master authorized networks ---"

# 1. Tạo VM nguồn để kiểm tra kết nối (nếu chưa có)
if gcloud compute instances describe source-instance --zone=$ZONE >/dev/null 2>&1; then
    echo "Instance source-instance đã tồn tại."
else
    gcloud compute instances create source-instance \
        --zone=$ZONE \
        --machine-type=e2-medium \
        --scopes 'https://www.googleapis.com/auth/cloud-platform' \
        --quiet
fi

# 2. Lấy External IP của source-instance
EXTERNAL_IP=$(gcloud compute instances describe source-instance --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

# 3. Cập nhật Authorized Networks cho cluster 1
echo "Đang cấp quyền truy cập cho IP: $EXTERNAL_IP/32..."
gcloud container clusters update private-cluster \
    --enable-master-authorized-networks \
    --master-authorized-networks $EXTERNAL_IP/32 \
    --zone=$ZONE \
    --quiet

echo "--- Task 5: Clean Up (Tùy chọn theo lab) ---"
# Lưu ý: Lab yêu cầu xóa cluster 1 trước khi tạo cluster 2 để tránh hết tài nguyên (Quota)
if gcloud container clusters describe private-cluster --zone=$ZONE >/dev/null 2>&1; then
    gcloud container clusters delete private-cluster --zone=$ZONE --quiet
fi

echo "--- Task 6: Create a private cluster with custom subnetwork ---"

# 1. Tạo Subnet tùy chỉnh (Idempotent)
if gcloud compute networks subnets describe my-subnet --region=$REGION >/dev/null 2>&1; then
    echo "Subnet my-subnet đã tồn tại."
else
    gcloud compute networks subnets create my-subnet \
        --network default \
        --range 10.0.4.0/22 \
        --enable-private-ip-google-access \
        --region=$REGION \
        --secondary-range my-svc-range=10.0.32.0/20,my-pod-range=10.4.0.0/14 \
        --quiet
fi

# 2. Tạo Cluster 2 sử dụng Subnet tùy chỉnh
if gcloud container clusters describe private-cluster2 --zone=$ZONE >/dev/null 2>&1; then
    echo "Cluster private-cluster2 đã tồn tại."
else
    gcloud beta container clusters create private-cluster2 \
        --enable-private-nodes \
        --enable-ip-alias \
        --master-ipv4-cidr 172.16.0.32/28 \
        --subnetwork my-subnet \
        --services-secondary-range-name my-svc-range \
        --cluster-secondary-range-name my-pod-range \
        --zone=$ZONE \
        --machine-type e2-medium \
        --quiet
fi

# 3. Cập nhật Authorized Networks cho cluster 2
echo "Đang cấp quyền truy cập cho cluster 2..."
gcloud container clusters update private-cluster2 \
    --enable-master-authorized-networks \
    --master-authorized-networks $EXTERNAL_IP/32 \
    --zone=$ZONE \
    --quiet

echo "--- TẤT CẢ CÁC TÁC VỤ ĐÃ HOÀN THÀNH ---"
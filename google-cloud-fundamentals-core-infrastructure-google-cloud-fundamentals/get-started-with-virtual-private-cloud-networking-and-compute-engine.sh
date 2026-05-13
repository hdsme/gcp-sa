#!/bin/bash

# 1. Gán giá trị trực tiếp từ thông tin Lab của bạn
PROJECT_ID=$(gcloud config get-value project)
ZONE_1="us-east4-a"       # Lấy từ mục Lab Zone trong bảng thông tin bên trái
REGION_1="us-east4"       # Lấy từ mục Lab Region
ZONE_2="asia-south1-b"
REGION_2="asia-south1"

echo "--- BẮT ĐẦU TRIỂN KHAI VPC  ---"

# 2. Xóa mạng default (Idempotent)
echo "Đang dọn dẹp mạng default..."
gcloud compute firewall-rules delete $(gcloud compute firewall-rules list --filter="network:default" --format="value(name)") --quiet 2>/dev/null
gcloud compute networks delete default --quiet 2>/dev/null

# 3. Tạo mạng mynetwork
if ! gcloud compute networks describe mynetwork > /dev/null 2>&1; then
    echo "Đang tạo mạng 'mynetwork'..."
    gcloud compute networks create mynetwork --subnet-mode=auto
    echo "Chờ subnet khởi tạo..."
    sleep 20
fi

# 4. Tạo Firewall rules
for rule in icmp custom rdp ssh; do
    NAME="mynetwork-allow-$rule"
    if ! gcloud compute firewall-rules describe $NAME > /dev/null 2>&1; then
        case $rule in
            icmp) gcloud compute firewall-rules create $NAME --network=mynetwork --allow=icmp --source-ranges=0.0.0.0/0 ;;
            custom) gcloud compute firewall-rules create $NAME --network=mynetwork --allow=tcp,udp,icmp --source-ranges=10.128.0.0/9 ;;
            rdp) gcloud compute firewall-rules create $NAME --network=mynetwork --allow=tcp:3389 --source-ranges=0.0.0.0/0 ;;
            ssh) gcloud compute firewall-rules create $NAME --network=mynetwork --allow=tcp:22 --source-ranges=0.0.0.0/0 ;;
        esac
    fi
done

# 5. Tạo VM instance 1 (Sửa lỗi parse resource)
echo "Đang tạo VM: mynet-us-vm tại $ZONE_1..."
if ! gcloud compute instances describe mynet-us-vm --zone=$ZONE_1 > /dev/null 2>&1; then
    gcloud compute instances create mynet-us-vm \
        --zone=$ZONE_1 \
        --machine-type=e2-micro \
        --network=mynetwork
else
    echo "Instance mynet-us-vm đã tồn tại."
fi

# 6. Tạo VM instance 2
echo "Đang tạo VM: mynet-r2-vm tại $ZONE_2..."
if ! gcloud compute instances describe mynet-r2-vm --zone=$ZONE_2 > /dev/null 2>&1; then
    gcloud compute instances create mynet-r2-vm \
        --zone=$ZONE_2 \
        --machine-type=e2-micro \
        --network=mynetwork
else
    echo "Instance mynet-r2-vm đã tồn tại."
fi

echo
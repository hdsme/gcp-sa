#!/bin/bash

# 1. Cấu hình biến (Thay đổi vùng theo yêu cầu của Lab nếu cần)
# Thông thường Qwiklabs sẽ cấp sẵn vùng, script này tự động lấy vùng mặc định
REGION_1=$(gcloud config get-value compute/region)
ZONE_1=$(gcloud config get-value compute/zone)
REGION_2="us-east1" # Ví dụ vùng thứ 2
ZONE_2="us-east1-b"

# Nếu REGION_1 trống, gán giá trị mặc định
[ -z "$REGION_1" ] && REGION_1="us-central1"
[ -z "$ZONE_1" ] && ZONE_1="us-central1-c"

echo "--- BẮT ĐẦU LAB: VPC Networking & Compute Engine ---"

# TASK 1: Dọn dẹp Network mặc định (Nếu còn tồn tại)
echo "Đang dọn dẹp firewall rules của mạng default..."
RULES=$(gcloud compute firewall-rules list --filter="network:default" --format="value(name)")
if [ ! -z "$RULES" ]; then
    gcloud compute firewall-rules delete $RULES --quiet
fi

echo "Đang xóa mạng default..."
if gcloud compute networks describe default > /dev/null 2>&1; then
    gcloud compute networks delete default --quiet
else
    echo "Mạng default đã được xóa hoặc không tồn tại."
fi


# TASK 2: Tạo VPC 'mynetwork' và VM Instances
echo "Đang tạo mạng 'mynetwork' (Auto mode)..."
if ! gcloud compute networks describe mynetwork > /dev/null 2>&1; then
    gcloud compute networks create mynetwork --subnet-mode=auto
else
    echo "Mạng 'mynetwork' đã tồn tại."
fi

echo "Đang tạo Firewall rules cho 'mynetwork'..."
# Tạo các rule chuẩn (ICMP, Internal, RDP, SSH)
FIREWALL_RULES=("icmp" "custom" "rdp" "ssh")
for rule in "${FIREWALL_RULES[@]}"; do
    RULE_NAME="mynetwork-allow-$rule"
    if ! gcloud compute firewall-rules describe $RULE_NAME > /dev/null 2>&1; then
        case $rule in
            icmp) gcloud compute firewall-rules create $RULE_NAME --network=mynetwork --allow=icmp --source-ranges=0.0.0.0/0 ;;
            custom) gcloud compute firewall-rules create $RULE_NAME --network=mynetwork --allow=tcp,udp,icmp --source-ranges=10.128.0.0/9 ;;
            rdp) gcloud compute firewall-rules create $RULE_NAME --network=mynetwork --allow=tcp:3389 --source-ranges=0.0.0.0/0 ;;
            ssh) gcloud compute firewall-rules create $RULE_NAME --network=mynetwork --allow=tcp:22 --source-ranges=0.0.0.0/0 ;;
        esac
    fi
done

echo "Đang tạo VM instance: mynet-us-vm ($REGION_1)..."
if ! gcloud compute instances describe mynet-us-vm --zone=$ZONE_1 > /dev/null 2>&1; then
    gcloud compute instances create mynet-us-vm \
        --zone=$ZONE_1 \
        --machine-type=e2-micro \
        --network=mynetwork
else
    echo "VM mynet-us-vm đã tồn tại."
fi

echo "Đang tạo VM instance: mynet-r2-vm ($REGION_2)..."
if ! gcloud compute instances describe mynet-r2-vm --zone=$ZONE_2 > /dev/null 2>&1; then
    gcloud compute instances create mynet-r2-vm \
        --zone=$ZONE_2 \
        --machine-type=e2-micro \
        --network=mynetwork
else
    echo "VM mynet-r2-vm đã tồn tại."
fi


# TASK 3: Kiểm tra kết nối (Optional)
echo "--- THÔNG TIN CÁC INSTANCE ---"
gcloud compute instances list --filter="name~'mynet-'"

echo "--- HOÀN THÀNH ---"
echo "Lưu ý: Để thực hiện Task 3 (xóa firewall test ping), bạn có thể dùng lệnh:"
echo "gcloud compute firewall-rules delete mynetwork-allow-icmp --quiet"
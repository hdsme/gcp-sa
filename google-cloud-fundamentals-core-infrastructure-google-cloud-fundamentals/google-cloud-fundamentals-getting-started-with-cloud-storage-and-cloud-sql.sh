#!/bin/bash

# 1. Cấu hình biến từ Lab
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
ZONE="us-central1-a"
BUCKET_NAME=$PROJECT_ID
DB_PASSWORD="Passw0rd1!"
INSTANCE_NAME="bloghost"

echo "--- BẮT ĐẦU TRIỂN KHAI LAB: STORAGE & SQL ---"

# 2. Tạo VM bloghost (Đảm bảo Task 2 hoàn thành)
if ! gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE > /dev/null 2>&1; then
    echo "Đang tạo VM $INSTANCE_NAME..."
    # Lệnh này bao gồm đầy đủ các tham số mà hệ thống Checkpoint tìm kiếm
    gcloud compute instances create $INSTANCE_NAME \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --machine-type=e2-standard-2 \
        --network-interface=network-tier=PREMIUM,subnet=default \
        --tags=http-server \
        --image-family=debian-12 \
        --image-project=debian-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-balanced \
        --metadata=startup-script='#!/bin/bash
apt-get update
apt-get install apache2 php php-mysql -y
service apache2 restart'
    
    # Tạo Firewall Rule cho HTTP (nếu chưa có)
    gcloud compute firewall-rules create default-allow-http-80 \
        --direction=INGRESS --priority=1000 --network=default --action=ALLOW \
        --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=http-server > /dev/null 2>&1 || true
else
    echo "VM $INSTANCE_NAME đã tồn tại."
fi

# Đợi 10 giây để VM ổn định và nhận IP
echo "Đang đợi lấy IP ngoại vi..."
sleep 10
VM_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].externalIp)')

# 3. Tạo Cloud Storage Bucket (Task 3)
if ! gcloud storage buckets describe gs://$BUCKET_NAME > /dev/null 2>&1; then
    echo "Đang tạo bucket $BUCKET_NAME..."
    gcloud storage buckets create gs://$BUCKET_NAME --location=US
    gcloud storage cp gs://cloud-training/gcpfci/my-excellent-blog.png .
    gcloud storage cp my-excellent-blog.png gs://$BUCKET_NAME/my-excellent-blog.png
    gsutil acl ch -u allUsers:R gs://$BUCKET_NAME/my-excellent-blog.png
fi

# 4. Tạo Cloud SQL Instance (Task 4)
if ! gcloud sql instances describe blog-db > /dev/null 2>&1; then
    echo "Đang tạo Cloud SQL blog-db (Vui lòng chờ)..."
    gcloud sql instances create blog-db \
        --database-version=MYSQL_8_0 \
        --tier=db-f1-micro \
        --region=$REGION \
        --root-password=$DB_PASSWORD \
        --storage-type=PD_SSD
fi

SQL_IP=$(gcloud sql instances describe blog-db --format='get(ipAddresses[0].ipAddress)')

# 5. Cấu hình User và Network cho SQL
echo "Đang cấu hình kết nối SQL cho IP: $VM_IP"
gcloud sql instances patch blog-db --authorized-networks=$VM_IP/32 --quiet
if ! gcloud sql users list --instance=blog-db | grep -q "blogdbuser"; then
    gcloud sql users create blogdbuser --instance=blog-db --password=$DB_PASSWORD
fi

# 6. Cấu hình ứng dụng PHP (Task 5 & 6)
echo "Đang cập nhật index.php lên máy chủ..."
IMAGE_URL="https://storage.googleapis.com/$BUCKET_NAME/my-excellent-blog.png"

cat <<EOF > index.php
<html>
<head><title>Welcome to my excellent blog</title></head>
<body>
<img src='$IMAGE_URL'>
<h1>Welcome to my excellent blog</h1>
<?php
\$dbserver = "$SQL_IP";
\$dbuser = "blogdbuser";
\$dbpassword = "$DB_PASSWORD";
try {
  \$conn = new PDO("mysql:host=\$dbserver;dbname=mysql", \$dbuser, \$dbpassword);
  \$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
  echo "Connected successfully";
} catch(PDOException \$e) {
  echo "Database connection failed: " . \$e->getMessage();
}
?>
</body></html>
EOF

gcloud compute scp index.php $INSTANCE_NAME:/tmp/index.php --zone=$ZONE --quiet
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --quiet --command="sudo mv /tmp/index.php /var/www/html/index.php && sudo service apache2 restart"

echo "--------------------------------------------------"
echo "HOÀN THÀNH! Hãy thử nhấn Check My Progress."
echo "Link Blog: http://$VM_IP/index.php"
echo "--------------------------------------------------"
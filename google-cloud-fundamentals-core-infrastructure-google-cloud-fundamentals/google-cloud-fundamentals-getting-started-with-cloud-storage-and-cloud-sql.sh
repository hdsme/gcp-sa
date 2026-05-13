#!/bin/bash

# 1. Cấu hình các biến (Thay đổi Region/Zone nếu cần theo yêu cầu của Lab)
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"  # Thay đổi theo region được cấp trong lab
ZONE="us-central1-a"   # Thay đổi theo zone được cấp trong lab
BUCKET_NAME=$PROJECT_ID
DB_PASSWORD="Passw0rd1!"
INSTANCE_NAME="bloghost"

echo "--- BẮT ĐẦU TRIỂN KHAI LAB: STORAGE & SQL ---"

# 2. Tạo VM bloghost (Task 2)
if ! gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE > /dev/null 2>&1; then
    echo "Đang tạo VM $INSTANCE_NAME..."
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=e2-standard-2 \
        --image-family=debian-12 \
        --image-project=debian-cloud \
        --tags=http-server \
        --metadata=startup-script='#!/bin/bash
apt-get update
apt-get install apache2 php php-mysql -y
service apache2 restart'
    
    # Đảm bảo có Firewall Rule cho HTTP
    gcloud compute firewall-rules create default-allow-http-80 \
        --direction=INGRESS --priority=1000 --network=default --action=ALLOW \
        --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=http-server > /dev/null 2>&1 || true
else
    echo "VM $INSTANCE_NAME đã tồn tại."
fi

# 3. Tạo Cloud Storage Bucket và upload ảnh (Task 3)
if ! gcloud storage buckets describe gs://$BUCKET_NAME > /dev/null 2>&1; then
    echo "Đang tạo bucket $BUCKET_NAME..."
    gcloud storage buckets create gs://$BUCKET_NAME --location=US
else
    echo "Bucket đã tồn tại."
fi

# Download và upload ảnh banner
if ! gcloud storage ls gs://$BUCKET_NAME/my-excellent-blog.png > /dev/null 2>&1; then
    echo "Đang upload ảnh banner..."
    gsutil cp gs://cloud-training/gcpfci/my-excellent-blog.png .
    gsutil cp my-excellent-blog.png gs://$BUCKET_NAME/
    gsutil acl ch -u allUsers:R gs://$BUCKET_NAME/my-excellent-blog.png
fi

# 4. Tạo Cloud SQL Instance (Task 4) - Bước này tốn khoảng 5-10 phút
if ! gcloud sql instances describe blog-db > /dev/null 2>&1; then
    echo "Đang tạo Cloud SQL blog-db (Vui lòng chờ khoảng 5-10 phút)..."
    gcloud sql instances create blog-db \
        --database-version=MYSQL_8_0 \
        --tier=db-f1-micro \
        --region=$REGION \
        --root-password=$DB_PASSWORD
else
    echo "SQL Instance blog-db đã tồn tại."
fi

# Lấy External IP của VM và Public IP của SQL
VM_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].externalIp)')
SQL_IP=$(gcloud sql instances describe blog-db --format='get(ipAddresses[0].ipAddress)')

# Ủy quyền cho IP của VM truy cập SQL
echo "Đang ủy quyền IP $VM_IP truy cập SQL..."
gcloud sql instances patch blog-db --authorized-networks=$VM_IP/32 --quiet

# Tạo SQL User
if ! gcloud sql users list --instance=blog-db | grep -q "blogdbuser"; then
    echo "Đang tạo user blogdbuser..."
    gcloud sql users create blogdbuser --instance=blog-db --password=$DB_PASSWORD
fi

# 5. Cấu hình index.php bên trong VM (Task 5 & 6)
echo "Đang cấu hình file index.php trên VM..."
IMAGE_URL="https://storage.googleapis.com/$BUCKET_NAME/my-excellent-blog.png"

# Tạo file PHP cục bộ
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

# Copy vào VM qua SSH
gcloud compute scp index.php $INSTANCE_NAME:/tmp/index.php --zone=$ZONE --quiet
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --quiet --command="sudo mv /tmp/index.php /var/www/html/index.php && sudo service apache2 restart"

echo "--------------------------------------------------"
echo "HOÀN THÀNH!"
echo "Truy cập blog tại: http://$VM_IP/index.php"
echo "--------------------------------------------------"
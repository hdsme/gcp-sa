#!/bin/bash

# 1. Khai báo biến từ Lab
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
ZONE="us-central1-a"
BUCKET_NAME=$PROJECT_ID
DB_PASSWORD="Passw0rd1!"
INSTANCE_NAME="bloghost"

echo "--- BẮT ĐẦU TRIỂN KHAI ---"

# 2. Tạo VM bloghost (Qwiklabs-safe)

if ! gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE >/dev/null 2>&1; then
    echo "Đang tạo VM bloghost..."
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=e2-standard-2 \
        --network-interface=subnet=default,address='',network-tier=PREMIUM \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --tags=http-server \
        --create-disk=auto-delete=yes,boot=yes,image-family=debian-12,image-project=debian-cloud,size=10,type=pd-balanced \
        --metadata=startup-script='#!/bin/bash
apt-get update
apt-get install -y apache2 php php-mysql
systemctl enable apache2
systemctl restart apache2' \
        --scopes=https://www.googleapis.com/auth/cloud-platform

fi

# 3. Mở Firewall Port 80
gcloud compute firewall-rules create default-allow-http-80 \
    --direction=INGRESS --priority=1000 --network=default --action=ALLOW \
    --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=http-server > /dev/null 2>&1 || true

# 4. LẤY IP VM (Quan trọng: Vòng lặp chờ IP sẵn sàng)
echo "Đang đợi máy ảo cấp IP..."
for i in {1..12}; do
    VM_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
    if [ ! -z "$VM_IP" ]; then
        echo "Lấy thành công VM_IP: $VM_IP"
        break
    fi
    echo "Đang thử lại ($i/12)..."
    sleep 5
done

if [ -z "$VM_IP" ]; then echo "LỖI: Không lấy được IP VM."; exit 1; fi

# 5. Cloud Storage (Task 3)
if ! gcloud storage buckets describe gs://$BUCKET_NAME > /dev/null 2>&1; then
    gcloud storage buckets create gs://$BUCKET_NAME --location=US
    gsutil cp gs://cloud-training/gcpfci/my-excellent-blog.png .
    gsutil cp my-excellent-blog.png gs://$BUCKET_NAME/
    gsutil acl ch -u allUsers:R gs://$BUCKET_NAME/my-excellent-blog.png
fi

# 6. Cloud SQL (Task 4)
if ! gcloud sql instances describe blog-db > /dev/null 2>&1; then
    echo "Đang tạo Cloud SQL blog-db (Vui lòng chờ)..."
    gcloud sql instances create blog-db \
        --database-version=MYSQL_8_0 --tier=db-f1-micro --region=$REGION --root-password=$DB_PASSWORD
fi

SQL_IP=$(gcloud sql instances describe blog-db --format='get(ipAddresses[0].ipAddress)')

# 7. Ủy quyền và tạo User (Đã fix lỗi /32)
echo "Đang ủy quyền IP $VM_IP cho SQL..."
gcloud sql instances patch blog-db --authorized-networks=$VM_IP/32 --quiet

if ! gcloud sql users list --instance=blog-db | grep -q "blogdbuser"; then
    gcloud sql users create blogdbuser --instance=blog-db --password=$DB_PASSWORD
fi

# 8. Cấu hình Website (Task 5 & 6)
IMAGE_URL="https://storage.googleapis.com/$BUCKET_NAME/my-excellent-blog.png"
cat <<EOF > index.php
<html><body>
<img src='$IMAGE_URL' style='width:500px'>
<h1>Welcome to my excellent blog</h1>
<?php
\$dbserver = "$SQL_IP";
\$dbuser = "blogdbuser";
\$dbpassword = "$DB_PASSWORD";
try {
  \$conn = new PDO("mysql:host=\$dbserver;dbname=mysql", \$dbuser, \$dbpassword);
  echo "Connected successfully to Cloud SQL!";
} catch(PDOException \$e) {
  echo "Connection failed: " . \$e->getMessage();
}
?>
</body></html>
EOF

gcloud compute scp index.php $INSTANCE_NAME:/tmp/index.php --zone=$ZONE --quiet
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --quiet --command="sudo mv /tmp/index.php /var/www/html/index.php && sudo service apache2 restart"

echo "--- HOÀN THÀNH ---"
echo "URL: http://$VM_IP/index.php"
#!/bin/bash

# Thiết lập các biến môi trường
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central" # Thay đổi nếu lab yêu cầu region khác

echo "--- Đang chuẩn bị môi trường và tải code ---"

# 1. Tải code từ source (Idempotent: chỉ tải nếu thư mục chưa tồn tại)
if [ ! -d "user-authentication-with-iap" ]; then
    gsutil cp gs://spls/gsp499/user-authentication-with-iap.zip .
    unzip user-authentication-with-iap.zip
    rm user-authentication-with-iap.zip
fi

cd user-authentication-with-iap

# --- Task 1: Deploy 1-HelloWorld ---
echo "--- Task 1: Deploying 1-HelloWorld ---"
cd 1-HelloWorld
# Cập nhật runtime sang python313
sed -i 's/python37/python313/g' app.yaml

# Deploy App Engine (Idempotent: gcloud sẽ cập nhật version nếu đã tồn tại)
gcloud app deploy --quiet --project=$PROJECT_ID

# Vô hiệu hóa Flex API để tránh xung đột với IAP cấu hình Standard (theo yêu cầu lab)
gcloud services disable appengineflex.googleapis.com --quiet


# --- Task 2: Access user identity information ---
echo "--- Task 2: Deploying 2-HelloUser ---"
cd ../2-HelloUser
sed -i 's/python37/python313/g' app.yaml
gcloud app deploy --quiet --project=$PROJECT_ID


# --- Task 3: Use Cryptographic Verification ---
echo "--- Task 3: Deploying 3-HelloVerifiedUser ---"
cd ../3-HelloVerifiedUser
sed -i 's/python37/python313/g' app.yaml
gcloud app deploy --quiet --project=$PROJECT_ID

echo "--- Hoàn tất quá trình Deploy ---"
echo "URL ứng dụng của bạn: https://$PROJECT_ID.appspot.com"

# --- Hướng dẫn cấu hình IAP (Vì lý do bảo mật và OAuth, phần này cần làm thủ công trên Console) ---
echo "------------------------------------------------------------"
echo "LƯU Ý: Các bước cấu hình IAP cần thực hiện trên giao diện Web:"
echo "1. Truy cập: Security > Identity-Aware Proxy"
echo "2. Configure OAuth Consent Screen (Internal)."
echo "3. Bật IAP cho 'App Engine app'."
echo "4. Thêm Member (Principal) là Email sinh viên của bạn với vai trò:"
echo "   'IAP-Secured Web App User'"
echo "------------------------------------------------------------"
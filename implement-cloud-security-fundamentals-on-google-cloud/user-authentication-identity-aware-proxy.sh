#!/bin/bash

# Thiết lập các biến môi trường
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central" 

echo "--- Đang chuẩn bị môi trường và tải code ---"

# 1. Tải code (Idempotent)
if [ ! -d "user-authentication-with-iap" ]; then
    gsutil cp gs://spls/gsp499/user-authentication-with-iap.zip .
    unzip user-authentication-with-iap.zip
    rm user-authentication-with-iap.zip
fi

# 2. Khởi tạo App Engine nếu chưa có (Sửa lỗi bạn gặp phải)
if ! gcloud app describe --project=$PROJECT_ID >/dev/null 2>&1; then
    echo "Đang khởi tạo App Engine tại $REGION..."
    gcloud app create --region=$REGION --project=$PROJECT_ID
else
    echo "App Engine đã được khởi tạo."
fi

cd user-authentication-with-iap

# --- Task 1: Deploy 1-HelloWorld ---
echo "--- Task 1: Deploying 1-HelloWorld ---"
cd 1-HelloWorld
sed -i 's/python37/python313/g' app.yaml
# Deploy và ép buộc sử dụng region đã chọn
gcloud app deploy --quiet --project=$PROJECT_ID

# Vô hiệu hóa Flex API (theo yêu cầu lab để tránh lỗi IAP)
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
echo "------------------------------------------------------------"
echo "BƯỚC TIẾP THEO (Thủ công trên Console):"
echo "1. Cấu hình OAuth Consent Screen (Internal)."
echo "2. Bật IAP tại: Security > Identity-Aware Proxy."
echo "3. Thêm Principal (Email student) với quyền 'IAP-Secured Web App User'."
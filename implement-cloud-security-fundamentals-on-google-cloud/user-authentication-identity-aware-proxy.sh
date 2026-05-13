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

# 2. Khởi tạo App Engine nếu chưa có
if ! gcloud app describe --project=$PROJECT_ID >/dev/null 2>&1; then
    echo "Đang khởi tạo App Engine tại $REGION..."
    gcloud app create --region=$REGION --project=$PROJECT_ID
else
    echo "App Engine đã được khởi tạo."
fi

# --- Hàm Deploy dùng chung để đảm bảo tính Idempotent ---
deploy_app() {
    local folder=$1
    echo "--- Đang Deploy thư mục: $folder ---"
    cd "$folder"
    # Cập nhật runtime sang python313 nếu chưa làm
    sed -i 's/python37/python313/g' app.yaml 2>/dev/null || true
    # Deploy app
    gcloud app deploy --quiet --project=$PROJECT_ID
    cd ..
}

cd user-authentication-with-iap

# --- Task 1: Deploy 1-HelloWorld ---
deploy_app "1-HelloWorld"

# Xử lý lỗi disable service: dùng || true để script tiếp tục chạy nếu gặp lỗi phân cấp
echo "Đang thử vô hiệu hóa App Engine Flex API (nếu có thể)..."
gcloud services disable appengineflex.googleapis.com --quiet || echo "Cảnh báo: Không thể tắt Flex API do giới hạn phân cấp của Qwiklabs. Bạn có thể bỏ qua lỗi này."

# --- Task 2: Access user identity information ---
deploy_app "2-HelloUser"

# --- Task 3: Use Cryptographic Verification ---
deploy_app "3-HelloVerifiedUser"

echo "--- Hoàn tất quá trình Deploy ---"
echo "URL ứng dụng: https://$PROJECT_ID.appspot.com"
echo "------------------------------------------------------------"
echo "BƯỚC TIẾP THEO (Thủ công trên Console):"
echo "1. Cấu hình OAuth Consent Screen: Security > API & Services > OAuth consent screen."
echo "2. Bật IAP tại: Security > Identity-Aware Proxy."
echo "3. Thêm Principal (Email student) với vai trò 'IAP-Secured Web App User'."
#!/bin/bash

# Thiết lập các biến môi trường
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME="${PROJECT_ID}-kms-lab"
export KEYRING_NAME="labkey"
export CRYPTOKEY_NAME="qwiklab"
export LOCATION="global"

echo "--- Task 1 & 2: Khởi tạo Storage Bucket và chuẩn bị dữ liệu ---"

# Tạo bucket nếu chưa tồn tại
if gsutil ls -b "gs://$BUCKET_NAME" >/dev/null 2>&1; then
    echo "Bucket $BUCKET_NAME đã tồn tại."
else
    gsutil mb gs://$BUCKET_NAME
fi

# Tải file dữ liệu mẫu
if [ ! -f "1.txt" ]; then
    gsutil cp gs://${PROJECT_ID}-kms-lab-data/finance-dept/inbox/1.txt .
fi

echo "--- Task 3 & 4: Kích hoạt KMS và tạo Keyring/Cryptokey ---"

# Kích hoạt Cloud KMS API
gcloud services enable cloudkms.googleapis.com

# Tạo KeyRing nếu chưa có
if gcloud kms keyrings describe $KEYRING_NAME --location $LOCATION >/dev/null 2>&1; then
    echo "KeyRing $KEYRING_NAME đã tồn tại."
else
    gcloud kms keyrings create $KEYRING_NAME --location $LOCATION
fi

# Tạo CryptoKey nếu chưa có
if gcloud kms keys describe $CRYPTOKEY_NAME --location $LOCATION --keyring $KEYRING_NAME >/dev/null 2>&1; then
    echo "CryptoKey $CRYPTOKEY_NAME đã tồn tại."
else
    gcloud kms keys create $CRYPTOKEY_NAME --location $LOCATION \
        --keyring $KEYRING_NAME \
        --purpose encryption
fi

echo "--- Task 5: Mã hóa dữ liệu đơn lẻ ---"

# Mã hóa file 1.txt bằng REST API (sử dụng curl)
PLAINTEXT=$(cat 1.txt | base64 -w0)

curl -s -X POST "https://cloudkms.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
  -d "{\"plaintext\":\"$PLAINTEXT\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type:application/json" \
| jq .ciphertext -r > 1.encrypted

# Tải file đã mã hóa lên Bucket
gsutil cp 1.encrypted gs://$BUCKET_NAME

echo "--- Task 6: Cấu hình quyền IAM ---"

USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')

# Gán quyền Admin và Encrypter/Decrypter (Idempotent)
gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location $LOCATION \
    --member "user:$USER_EMAIL" \
    --role "roles/cloudkms.admin" --quiet >/dev/null

gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location $LOCATION \
    --member "user:$USER_EMAIL" \
    --role "roles/cloudkms.cryptoKeyEncrypterDecrypter" --quiet >/dev/null

echo "--- Task 7: Sao lưu và mã hóa hàng loạt ---"

# Tải toàn bộ thư mục finance-dept
if [ ! -d "finance-dept" ]; then
    gsutil -m cp -r gs://${PROJECT_ID}-kms-lab-data/finance-dept .
fi

# Vòng lặp mã hóa tất cả các file trong thư mục
FILES=$(find finance-dept -type f -not -name "*.encrypted")
for file in $FILES; do
    # Chỉ mã hóa nếu file .encrypted chưa tồn tại
    if [ ! -f "${file}.encrypted" ]; then
        PLAINTEXT_FILE=$(cat "$file" | base64 -w0)
        curl -s -X POST "https://cloudkms.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
            -d "{\"plaintext\":\"$PLAINTEXT_FILE\"}" \
            -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
            -H "Content-Type:application/json" \
        | jq .ciphertext -r > "${file}.encrypted"
    fi
done

# Upload các file đã mã hóa lên bucket
gsutil -m cp finance-dept/inbox/*.encrypted gs://$BUCKET_NAME/finance-dept/inbox

echo "--- Hoàn thành tất cả các tác vụ ---"
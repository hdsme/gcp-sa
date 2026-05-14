#!/bin/bash

# Hiển thị màu sắc cho các thông báo
green='\033[0;32m'
plain='\033[0m'

echo -e "${green}--- Bắt đầu xử lý lab Hello Cloud Run ---${plain}"

# 1. Cấu hình môi trường
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)
echo "Nhập Region (ví dụ: us-east4):"
read REGION
gcloud config set compute/region $REGION
export LOCATION=$REGION

# 2. Bật các API cần thiết
echo -e "${green}--- Đang bật Cloud Run và Artifact Registry API...${plain}"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com

# 3. Tạo ứng dụng Node.js
echo -e "${green}--- Đang khởi tạo source code...${plain}"
mkdir -p helloworld && cd helloworld

# Tạo package.json
cat <<EOF > package.json
{
  "name": "helloworld",
  "description": "Simple hello world sample in Node",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "author": "Google LLC",
  "license": "Apache-2.0",
  "dependencies": {
    "express": "^4.17.1"
  }
}
EOF

# Tạo index.js
cat <<EOF > index.js
const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.get('/', (req, res) => {
  const name = process.env.NAME || 'World';
  res.send(\`Hello \${name}!\`);
});

app.listen(port, () => {
  console.log(\`helloworld: listening on port \${port}\`);
});
EOF

# 4. Tạo Artifact Registry
echo -e "${green}--- Đang tạo Docker repository...${plain}"
gcloud artifacts repositories create my-repository \
    --repository-format=docker \
    --location=$LOCATION \
    --description="Docker repository"

gcloud auth configure-docker $LOCATION-docker.pkg.dev --quiet

# 5. Container hóa với Cloud Build
echo -e "${green}--- Đang build và push image lên Artifact Registry...${plain}"
cat <<EOF > Dockerfile
FROM node:20-slim
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --only=production
COPY . ./
CMD [ "npm", "start" ]
EOF

gcloud builds submit --tag $LOCATION-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/my-repository/helloworld

# 6. Deploy lên Cloud Run
echo -e "${green}--- Đang deploy lên Cloud Run...${plain}"
gcloud run deploy helloworld \
    --image $LOCATION-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/my-repository/helloworld \
    --allow-unauthenticated \
    --region=$LOCATION

echo -e "${green}--- HOÀN THÀNH! Kiểm tra URL ở trên để xem kết quả. ---${plain}"
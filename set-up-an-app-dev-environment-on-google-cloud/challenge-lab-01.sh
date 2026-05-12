#!/bin/bash

# Set Variables
PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="qwiklabs-gcp-00-b6b10394c586-bucket"
TOPIC_NAME="topic-memories-568"
REGION="us-central1"
FUNCTION_NAME="memories-thumbnail-maker"
PREVIOUS_ENGINEER="student-00-e6f830c1366e@qwiklabs.net"

# 1. Create a Bucket
gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION

# 2. Create a Pub/Sub Topic
gcloud pubsub topics create $TOPIC_NAME

# 3. Prepare Cloud Run Function code
mkdir -p $FUNCTION_NAME && cd $FUNCTION_NAME

cat <<EOF > index.js
const functions = require('@google-cloud/functions-framework');
const { Storage } = require('@google-cloud/storage');
const { PubSub } = require('@google-cloud/pubsub');
const sharp = require('sharp');

functions.cloudEvent('memories-thumbnail-maker', async cloudEvent => {
  const event = cloudEvent.data;
  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = new Storage().bucket(bucketName);
  const topicName = "$TOPIC_NAME";
  const pubsub = new PubSub();
  if (fileName.search("64x64_thumbnail") === -1) {
    const filename_split = fileName.split('.');
    const filename_ext = filename_split[filename_split.length - 1].toLowerCase();
    const filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length - 1);
    if (filename_ext === 'png' || filename_ext === 'jpg' || filename_ext === 'jpeg') {
      const gcsObject = bucket.file(fileName);
      const newFilename = \`\${filename_without_ext}_64x64_thumbnail.\${filename_ext}\`;
      const gcsNewObject = bucket.file(newFilename);
      try {
        const [buffer] = await gcsObject.download();
        const resizedBuffer = await sharp(buffer)
          .resize(64, 64, { fit: 'inside', withoutEnlargement: true })
          .toFormat(filename_ext)
          .toBuffer();
        await gcsNewObject.save(resizedBuffer, { metadata: { contentType: \`image/\${filename_ext}\` } });
        await pubsub.topic(topicName).publishMessage({ data: Buffer.from(newFilename) });
      } catch (err) {
        console.error(\`Error: \${err}\`);
      }
    }
  }
});
EOF

cat <<EOF > package.json
{
  "name": "thumbnails",
  "version": "1.0.0",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0",
    "@google-cloud/pubsub": "^2.0.0",
    "@google-cloud/storage": "^6.11.0",
    "sharp": "^0.32.1"
  }
}
EOF

# 4. Deploy the Cloud Run Function (2nd Gen)
gcloud functions deploy $FUNCTION_NAME \
  --gen2 \
  --runtime=nodejs22 \
  --region=$REGION \
  --source=. \
  --entry-point=$FUNCTION_NAME \
  --trigger-bucket=$BUCKET_NAME \
  --allow-unauthenticated

# 5. Remove the previous cloud engineer
cd ..
gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="user:$PREVIOUS_ENGINEER" \
  --role="roles/viewer"

echo "Lab setup complete!"
#!/bin/bash

# Set project-specific variables
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-west1"
export ZONE="us-west1-a"

# Set the default region
gcloud config set compute/region $REGION

echo "--- Task 1: Create and manage service accounts ---"

# 1. Create my-sa-123 if it doesn't exist
if ! gcloud iam service-accounts describe my-sa-123@$PROJECT_ID.iam.gserviceaccount.com >/dev/null 2>&1; then
    gcloud iam service-accounts create my-sa-123 --display-name "my service account"
    echo "Service account my-sa-123 created."
    sleep 5 # Wait for IAM propagation
else
    echo "Service account my-sa-123 already exists."
fi

# 2. Grant Editor role (Safe to re-run)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:my-sa-123@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/editor" --quiet >/dev/null


echo "--- Task 2: Create BigQuery Service Account and VM ---"

# 1. Create bigquery-qwiklab if it doesn't exist
if ! gcloud iam service-accounts describe bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com >/dev/null 2>&1; then
    gcloud iam service-accounts create bigquery-qwiklab --display-name "bigquery-qwiklab"
    echo "Service account bigquery-qwiklab created."
    sleep 5
else
    echo "Service account bigquery-qwiklab already exists."
fi

# 2. Grant BigQuery roles (Safe to re-run)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/bigquery.dataViewer" --quiet >/dev/null

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/bigquery.user" --quiet >/dev/null

# 3. Create VM instance if it doesn't exist
if ! gcloud compute instances describe bigquery-instance --zone=$ZONE >/dev/null 2>&1; then
    gcloud compute instances create bigquery-instance \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --machine-type=e2-medium \
        --network-interface=network-tier=PREMIUM,subnet=default \
        --service-account="bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com" \
        --scopes="https://www.googleapis.com/auth/bigquery,https://www.googleapis.com/auth/cloud-platform" \
        --image-project=debian-cloud --image-family=debian-12 \
        --quiet
else
    echo "VM instance bigquery-instance already exists."
fi


echo "--- Task 3: Setup and Run BigQuery Query ---"

# Use SSH with a "StrictHostKeyChecking=no" flag for automation
gcloud compute ssh bigquery-instance --zone=$ZONE --tunnel-through-iap --command="
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv
python3 -m venv myvenv
source myvenv/bin/activate
pip3 install --upgrade pip
pip3 install google-cloud-bigquery pyarrow pandas db-dtypes

cat <<EOF > query.py
from google.auth import compute_engine
from google.cloud import bigquery

credentials = compute_engine.Credentials(
    service_account_email='bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com')

query = '''
SELECT year, COUNT(1) as num_babies
FROM publicdata.samples.natality
WHERE year > 2000
GROUP BY year
'''

client = bigquery.Client(project='$PROJECT_ID', credentials=credentials)
print(client.query(query).to_dataframe())
EOF

python3 query.py
"

echo "Lab tasks completed."
#!/bin/bash

# Service Accounts and Roles: Fundamentals - Automation Script

# Set project-specific variables
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-west1"
export ZONE="us-west1-a"

# Set the default region
gcloud config set compute/region $REGION

# --- Task 1: Create and manage service accounts ---

# 1. Create a service account (my-sa-123)
gcloud iam service-accounts create my-sa-123 --display-name "my service account"

# 2. Grant the Editor role to the service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:my-sa-123@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/editor"


# --- Task 2: Create BigQuery Service Account and VM ---

# 1. Create the bigquery-qwiklab service account
gcloud iam service-accounts create bigquery-qwiklab --display-name "bigquery-qwiklab"

# 2. Grant BigQuery Data Viewer role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/bigquery.dataViewer"

# 3. Grant BigQuery User role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/bigquery.user"

# 4. Create a VM instance with the service account and BigQuery scope enabled
gcloud compute instances create bigquery-instance \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --network-interface=network-tier=PREMIUM,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account="bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com" \
    --scopes="https://www.googleapis.com/auth/bigquery,https://www.googleapis.com/auth/cloud-platform" \
    --create-disk=auto-delete=yes,boot=yes,device-name=bigquery-instance,image=projects/debian-cloud/global/images/family/debian-12,mode=rw,size=10,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any

# Wait for VM to initialize
echo "Waiting for VM to initialize..."
sleep 30

# --- Task 3: Setup and Run BigQuery Query on the VM ---

# Use gcloud compute ssh to run setup commands and the python script remotely
gcloud compute ssh bigquery-instance --zone=$ZONE --command="
sudo apt-get update
sudo apt-get install -y git python3-pip python3-venv
python3 -m venv myvenv
source myvenv/bin/activate
pip3 install --upgrade pip
pip3 install google-cloud-bigquery pyarrow pandas db-dtypes

# Create the Python script
echo \"
from google.auth import compute_engine
from google.cloud import bigquery

credentials = compute_engine.Credentials(
    service_account_email='bigquery-qwiklab@$PROJECT_ID.iam.gserviceaccount.com')

query = '''
SELECT
  year,
  COUNT(1) as num_babies
FROM
  publicdata.samples.natality
WHERE
  year > 2000
GROUP BY
  year
'''

client = bigquery.Client(
    project='$PROJECT_ID',
    credentials=credentials)
print(client.query(query).to_dataframe())
\" > query.py

# Run the query
python3 query.py
"

echo "Lab tasks completed successfully."
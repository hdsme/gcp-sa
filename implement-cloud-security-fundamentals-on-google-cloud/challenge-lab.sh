#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Configuration ---
# Replace these with the actual values provided in your lab instructions
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-east1"
export ZONE="us-east1-b"
export ROLE_NAME="orca_storage_update"
export SERVICE_ACCOUNT_NAME="orca-service-account"
export CLUSTER_NAME="orca-test-cluster"
export NETWORK="orca-build-vpc"
export SUBNET="orca-build-subnet"

# 1. Create a custom security role
gcloud iam roles create $ROLE_NAME --project=$PROJECT_ID \
    --title="Custom Security Role" \
    --description="Permissions to add and update objects in GCS" \
    --permissions="storage.buckets.get,storage.objects.get,storage.objects.list,storage.objects.update,storage.objects.create" \
    --stage=GA

# 2. Create a service account
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="Orca Service Account"

# 3. Bind roles to the service account
# Bind the custom role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="projects/$PROJECT_ID/roles/$ROLE_NAME"

# Bind required GKE roles
for role in roles/monitoring.viewer roles/monitoring.metricWriter roles/logging.logWriter; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="$role"
done

# 4. Create the Private GKE Cluster
# Note: We enable master authorized networks but will add the jump host IP in the next step
gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --release-channel="regular" \
    --network=$NETWORK \
    --subnetwork=$SUBNET \
    --service-account="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --enable-ip-alias \
    --enable-private-nodes \
    --enable-master-authorized-networks \
    --master-ipv4-cidr="172.16.0.0/28" \
    --no-enable-basic-auth \
    --metadata disable-legacy-endpoints=true

# Get the Internal IP of the jumphost to authorize it
JUMP_HOST_IP=$(gcloud compute instances describe orca-jumphost --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')

# Update cluster to authorize the jumphost
gcloud container clusters update $CLUSTER_NAME \
    --zone=$ZONE \
    --enable-master-authorized-networks \
    --master-authorized-networks="${JUMP_HOST_IP}/32"

echo "Build script complete. Connect to orca-jumphost to perform Task 5."
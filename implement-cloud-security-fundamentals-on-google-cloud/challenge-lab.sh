#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Updated Lab Configuration ---
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-west1"
export ZONE="us-west1-c"

# Specific values from your lab credentials
export ROLE_NAME="orca_storage_editor_387"
export SERVICE_ACCOUNT_NAME="orca-private-cluster-783-sa"
export CLUSTER_NAME="orca-cluster-931"

# Network details from lab scenario
export NETWORK="orca-build-vpc"
export SUBNET="orca-build-subnet"

echo "Step 1: Creating custom security role..."
gcloud iam roles create $ROLE_NAME --project=$PROJECT_ID \
    --title="Orca Storage Editor" \
    --description="Permissions to add and update objects in GCS" \
    --permissions="storage.buckets.get,storage.objects.get,storage.objects.list,storage.objects.update,storage.objects.create" \
    --stage=GA

echo "Step 2: Creating service account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="Orca Private Cluster Service Account"

echo "Step 3: Binding roles to the service account..."
# Custom Role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="projects/$PROJECT_ID/roles/$ROLE_NAME"

# Required GKE roles
for role in roles/monitoring.viewer roles/monitoring.metricWriter roles/logging.logWriter; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="$role"
done

echo "Step 4: Creating Private GKE Cluster..."
# Creating the cluster with private endpoint and master authorized networks enabled
gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --network=$NETWORK \
    --subnetwork=$SUBNET \
    --service-account="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --enable-ip-alias \
    --enable-private-nodes \
    --enable-private-endpoint \
    --enable-master-authorized-networks \
    --master-ipv4-cidr="172.16.0.0/28" \
    --no-enable-basic-auth \
    --metadata disable-legacy-endpoints=true

echo "Step 5: Authorizing the Jumphost..."
# Get the Internal IP of the orca-jumphost
JUMP_HOST_IP=$(gcloud compute instances describe orca-jumphost --zone=$ZONE --format='get(networkInterfaces[0].networkIP)')

# Update cluster to authorize the jumphost internal IP
gcloud container clusters update $CLUSTER_NAME \
    --zone=$ZONE \
    --enable-master-authorized-networks \
    --master-authorized-networks="${JUMP_HOST_IP}/32"

echo "Infrastructure setup complete. Use the orca-jumphost to deploy the application."
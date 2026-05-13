#!/bin/bash

# VPC Network Peering - Automation Script

# Variables from lab context
# Replace these if your Project IDs are different
PROJECT_ID_A="qwiklabs-gcp-03-b277a73a27ef"
PROJECT_ID_B="qwiklabs-gcp-03-285f6a45423d"

echo "--- Task 1: Create custom networks and instances ---"

# --- Setup Project A ---
echo "Configuring Project A ($PROJECT_ID_A)..."
gcloud config set project $PROJECT_ID_A

# Create Network A if it doesn't exist
if ! gcloud compute networks describe network-a --project=$PROJECT_ID_A >/dev/null 2>&1; then
    gcloud compute networks create network-a --subnet-mode=custom --project=$PROJECT_ID_A
fi

# Create Subnet A
if ! gcloud compute networks subnets describe network-a-subnet --region=us-east4 --project=$PROJECT_ID_A >/dev/null 2>&1; then
    gcloud compute networks subnets create network-a-subnet \
        --network=network-a \
        --range=10.0.0.0/16 \
        --region=us-east4 \
        --project=$PROJECT_ID_A
fi

# Create VM A
if ! gcloud compute instances describe vm-a --zone=us-east4-c --project=$PROJECT_ID_A >/dev/null 2>&1; then
    gcloud compute instances create vm-a \
        --zone=us-east4-c \
        --network=network-a \
        --subnet=network-a-subnet \
        --machine-type=e2-small \
        --project=$PROJECT_ID_A
fi

# Firewall A
gcloud compute firewall-rules create network-a-fw --network=network-a --allow=tcp:22,icmp --project=$PROJECT_ID_A --quiet


# --- Setup Project B ---
echo "Configuring Project B ($PROJECT_ID_B)..."
gcloud config set project $PROJECT_ID_B

# Create Network B
if ! gcloud compute networks describe network-b --project=$PROJECT_ID_B >/dev/null 2>&1; then
    gcloud compute networks create network-b --subnet-mode=custom --project=$PROJECT_ID_B
fi

# Create Subnet B
if ! gcloud compute networks subnets describe network-b-subnet --region=us-central1 --project=$PROJECT_ID_B >/dev/null 2>&1; then
    gcloud compute networks subnets create network-b-subnet \
        --network=network-b \
        --range=10.8.0.0/16 \
        --region=us-central1 \
        --project=$PROJECT_ID_B
fi

# Create VM B
if ! gcloud compute instances describe vm-b --zone=us-central1-b --project=$PROJECT_ID_B >/dev/null 2>&1; then
    gcloud compute instances create vm-b \
        --zone=us-central1-b \
        --network=network-b \
        --subnet=network-b-subnet \
        --machine-type=e2-small \
        --project=$PROJECT_ID_B
fi

# Firewall B
gcloud compute firewall-rules create network-b-fw --network=network-b --allow=tcp:22,icmp --project=$PROJECT_ID_B --quiet


echo "--- Task 2: Set up VPC network peering session ---"

# Peer Network A -> Network B
echo "Creating peering from A to B..."
gcloud compute networks peerings create peer-ab \
    --network=network-a \
    --peer-project=$PROJECT_ID_B \
    --peer-network=network-b \
    --project=$PROJECT_ID_A

# Peer Network B -> Network A
echo "Creating peering from B to A..."
gcloud compute networks peerings create peer-ba \
    --network=network-b \
    --peer-project=$PROJECT_ID_A \
    --peer-network=network-a \
    --project=$PROJECT_ID_B

echo "--- Task 3: Verifying routes ---"
gcloud compute routes list --project=$PROJECT_ID_A --filter="network:network-a"

echo "Setup complete. You can now test connectivity by pinging between VM-A and VM-B."
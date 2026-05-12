#!/bin/bash

# ==============================================================================
# CONFIGURATION - Update these with the values provided in your lab
# ==============================================================================
export REGION="us-central1"
export ZONE="us-central1-a"

echo "🚀 Starting Network Load Balancer setup in $REGION ($ZONE)..."

# Task 1: Set default region and zone
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Task 2: Create three web server instances
for i in {1..3}; do
  echo "🖥️ Creating instance www$i..."
  gcloud compute instances create www$i \
    --zone=$ZONE \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script="#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo '<h3>Web Server: www$i</h3>' | tee /var/www/html/index.html"
done

# Create firewall rule
echo "🛡️ Creating firewall rule..."
gcloud compute firewall-rules create www-firewall-network-lb \
    --target-tags network-lb-tag --allow tcp:80

# Task 3: Configure the load balancing service
echo "🌐 Creating static IP address..."
gcloud compute addresses create network-lb-ip-1 --region $REGION

echo "🏥 Creating HTTP health check..."
gcloud compute http-health-checks create basic-check

# Task 4: Create target pool and forwarding rule
echo "🎯 Creating target pool..."
gcloud compute target-pools create www-pool \
    --region $REGION --http-health-check basic-check

echo "➕ Adding instances to the pool..."
gcloud compute target-pools add-instances www-pool \
    --instances www1,www2,www3

echo "🏗️ Creating forwarding rule..."
gcloud compute forwarding-rules create www-rule \
    --region $REGION \
    --ports 80 \
    --address network-lb-ip-1 \
    --target-pool www-pool

# Task 5: Verification
echo "✅ Setup Complete!"
IPADDRESS=$(gcloud compute forwarding-rules describe www-rule --region $REGION --format="json" | jq -r .IPAddress)
echo "Load Balancer IP: $IPADDRESS"
echo "Waiting 30 seconds for instances to report healthy..."
sleep 30

echo "Testing traffic distribution (5 requests):"
for i in {1..5}; do curl -m1 $IPADDRESS; done
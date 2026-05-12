#!/bin/bash

# ==============================================================================
# CONFIGURATION - Update these with the values provided in your lab
# ==============================================================================
export REGION="us-west1"
export ZONE="us-west1-b"

echo "🚀 Starting Application Load Balancer setup..."

# Task 1: Set the default region and zone
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Task 2: Create three web server instances (Manual)
echo "🖥️ Creating manual web server instances..."
for i in {1..3}; do
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

gcloud compute firewall-rules create www-firewall-network-lb \
    --target-tags network-lb-tag --allow tcp:80

# Task 3: Create an Application Load Balancer
echo "🏗️ Creating instance template..."
gcloud compute instance-templates create lb-backend-template \
   --region=$REGION \
   --network=default \
   --subnet=default \
   --tags=allow-health-check \
   --machine-type=e2-medium \
   --image-family=debian-11 \
   --image-project=debian-cloud \
   --metadata=startup-script="#!/bin/bash
     apt-get update
     apt-get install apache2 -y
     a2ensite default-ssl
     a2enmod ssl
     vm_hostname=\"\$(curl -H \"Metadata-Flavor:Google\" http://169.254.169.254/computeMetadata/v1/instance/name)\"
     echo \"Page served from: \$vm_hostname\" | tee /var/www/html/index.html
     systemctl restart apache2"

echo "📦 Creating managed instance group..."
gcloud compute instance-groups managed create lb-backend-group \
   --template=lb-backend-template --size=2 --zone=$ZONE

echo "🛡️ Creating health check firewall rule..."
gcloud compute firewall-rules create fw-allow-health-check \
    --network=default \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=allow-health-check \
    --rules=tcp:80

echo "🌐 Reserving global static IP..."
gcloud compute addresses create lb-ipv4-1 --ip-version=IPV4 --global

echo "🏥 Creating health check..."
gcloud compute health-checks create http http-basic-check --port 80

echo "⚙️ Creating backend service..."
gcloud compute backend-services create web-backend-service \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=http-basic-check \
    --global

echo "➕ Adding instance group to backend service..."
gcloud compute backend-services add-backend web-backend-service \
    --instance-group=lb-backend-group \
    --instance-group-zone=$ZONE \
    --global

echo "🗺️ Creating URL map..."
gcloud compute url-maps create web-map-http --default-service web-backend-service

echo "🔌 Creating target HTTP proxy..."
gcloud compute target-http-proxies create http-lb-proxy --url-map web-map-http

echo "⚓ Creating global forwarding rule..."
gcloud compute forwarding-rules create http-content-rule \
    --address=lb-ipv4-1 \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80

# Task 4: Output verification details
echo "✅ Setup Complete!"
LB_IP=$(gcloud compute addresses describe lb-ipv4-1 --format="get(address)" --global)
echo "-------------------------------------------------------"
echo "Load Balancer IP: $LB_IP"
echo "Note: It may take 3-5 minutes for the Load Balancer to become active."
echo "You can test with: curl http://$LB_IP"
echo "-------------------------------------------------------"
#!/bin/bash

# ==============================================================================
# CONFIGURATION - Update these with the values provided in your lab
# ==============================================================================
export REGION="asia-south1"
export ZONE="asia-south1-b"

echo "🚀 Starting Challenge Lab: Implement Load Balancing on Compute Engine..."

# Set defaults
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# ------------------------------------------------------------------------------
# TASK 1: Create multiple web server instances
# ------------------------------------------------------------------------------
echo "🖥️ Creating web1, web2, and web3..."
for i in {1..3}; do
  gcloud compute instances create web$i \
    --zone=$ZONE \
    --machine-type=e2-small \
    --tags=network-lb-tag \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --metadata=startup-script="#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo '<h3>Web Server: web$i</h3>' | tee /var/www/html/index.html"
done

echo "🛡️ Creating firewall rule for Network LB..."
gcloud compute firewall-rules create www-firewall-network-lb \
    --target-tags network-lb-tag --allow tcp:80

# ------------------------------------------------------------------------------
# TASK 2: Configure the Network Load Balancing service
# ------------------------------------------------------------------------------
echo "🌐 Reserving static IP for Network LB..."
gcloud compute addresses create network-lb-ip-1 --region $REGION

echo "🎯 Creating target pool..."
gcloud compute target-pools create www-pool --region $REGION

echo "➕ Adding instances to target pool..."
gcloud compute target-pools add-instances www-pool \
    --instances web1,web2,web3 --instances-zone $ZONE

echo "🏗️ Creating forwarding rule..."
gcloud compute forwarding-rules create www-rule \
    --region $REGION \
    --ports 80 \
    --address network-lb-ip-1 \
    --target-pool www-pool

# ------------------------------------------------------------------------------
# TASK 3: Create an HTTP Load Balancer
# ------------------------------------------------------------------------------
echo "🏗️ Creating instance template for HTTP LB..."
gcloud compute instance-templates create lb-backend-template \
   --region=$REGION \
   --network=default \
   --subnet=default \
   --tags=allow-health-check \
   --machine-type=e2-medium \
   --image-family=debian-12 \
   --image-project=debian-cloud \
   --metadata=startup-script="#!/bin/bash
     apt-get update
     apt-get install apache2 -y
     vm_hostname=\"\$(curl -H \"Metadata-Flavor:Google\" http://169.254.169.254/computeMetadata/v1/instance/name)\"
     echo \"Page served from: \$vm_hostname\" | tee /var/www/html/index.html
     systemctl restart apache2"

echo "📦 Creating managed instance group (MIG)..."
gcloud compute instance-groups managed create lb-backend-group \
   --template=lb-backend-template --size=2 --zone=$ZONE

echo "🛡️ Creating Google health check firewall rule..."
gcloud compute firewall-rules create fw-allow-health-check \
    --network=default \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=allow-health-check \
    --rules=tcp:80

echo "🌐 Reserving global static IP for HTTP LB..."
gcloud compute addresses create lb-ipv4-1 --ip-version=IPV4 --global

echo "🏥 Creating HTTP health check..."
gcloud compute health-checks create http http-basic-check --port 80

echo "⚙️ Creating backend service..."
gcloud compute backend-services create web-backend-service \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=http-basic-check \
    --global

echo "➕ Adding MIG to backend service..."
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

echo "✅ Challenge Lab resources deployed!"
HTTP_LB_IP=$(gcloud compute addresses describe lb-ipv4-1 --format="get(address)" --global)
NET_LB_IP=$(gcloud compute addresses describe network-lb-ip-1 --format="get(address)" --region $REGION)

echo "-------------------------------------------------------"
echo "Network LB IP: $NET_LB_IP"
echo "HTTP LB IP:    $HTTP_LB_IP"
echo "-------------------------------------------------------"
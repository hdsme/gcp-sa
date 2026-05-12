#!/bin/bash

# ==============================================================================
# CONFIGURATION - Update these with the values provided in your lab
# ==============================================================================
export REGION="us-central1"
export ZONE="us-central1-a"

export ILB_IP="REPLACE_WITH_INTERNAL_IP" # Usually something like 10.128.0.5

echo "🚀 Starting Internal Application Load Balancer setup..."

# Task 1: Set defaults
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Task 2: Create Backend Managed Instance Group
echo "📝 Creating backend startup script..."
cat << EOF > backend.sh
#!/bin/bash
sudo chmod -R 777 /usr/local/sbin/
sudo cat << 'PYTHON_EOF' > /usr/local/sbin/serveprimes.py
import http.server
def is_prime(a): return a!= 1 and all(a % i for i in range(2, int(a**0.5)+1))
class myHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(s):
        s.send_response(200)
        s.send_header("Content-type", "text/plain")
        s.end_headers()
        s.wfile.write(bytes(str(is_prime(int(s.path[1:]))).encode('utf-8')))
http.server.HTTPServer(("", 80),myHandler).serve_forever()
PYTHON_EOF
nohup python3 /usr/local/sbin/serveprimes.py > /dev/null 2>&1 &
EOF

echo "🏗️ Creating instance template..."
gcloud compute instance-templates create primecalc \
    --metadata-from-file startup-script=backend.sh \
    --no-address \
    --tags backend \
    --machine-type=e2-medium

echo "🛡️ Opening backend firewall (Port 80)..."
gcloud compute firewall-rules create http --network default --allow=tcp:80 \
    --source-ranges 0.0.0.0/0 --target-tags backend

echo "📦 Creating managed instance group..."
gcloud compute instance-groups managed create backend \
    --size 3 \
    --template primecalc \
    --zone $ZONE

# Task 3: Set up Internal Load Balancer
echo "🏥 Creating health check..."
gcloud compute health-checks create http ilb-health --request-path /2

echo "⚙️ Creating backend service..."
gcloud compute backend-services create prime-service \
    --load-balancing-scheme internal \
    --region $REGION \
    --protocol tcp \
    --health-checks ilb-health

echo "➕ Adding instance group to backend service..."
gcloud compute backend-services add-backend prime-service \
    --instance-group backend \
    --instance-group-zone $ZONE \
    --region $REGION

echo "⚓ Creating internal forwarding rule..."
gcloud compute forwarding-rules create prime-lb \
    --load-balancing-scheme internal \
    --ports 80 \
    --network default \
    --region $REGION \
    --address $ILB_IP \
    --backend-service prime-service

# Task 5: Create Public-facing Web Server
echo "📝 Creating frontend startup script..."
cat << EOF > frontend.sh
#!/bin/bash
sudo chmod -R 777 /usr/local/sbin/
sudo cat << 'PYTHON_EOF' > /usr/local/sbin/getprimes.py
import urllib.request
from multiprocessing.dummy import Pool as ThreadPool
import http.server
PREFIX="http://$ILB_IP/"
def get_url(number): return urllib.request.urlopen(PREFIX+str(number)).read().decode('utf-8')
class myHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(s):
        s.send_response(200)
        s.send_header("Content-type", "text/html")
        s.end_headers()
        i = int(s.path[1:]) if (len(s.path)>1) else 1
        s.wfile.write("<html><body><table>".encode('utf-8'))
        pool = ThreadPool(10)
        results = pool.map(get_url,range(i,i+100))
        for x in range(0,100):
            if not (x % 10): s.wfile.write("<tr>".encode('utf-8'))
            if results[x]=="True":
                s.wfile.write("<td bgcolor='#00ff00'>".encode('utf-8'))
            else:
                s.wfile.write("<td bgcolor='#ff0000'>".encode('utf-8'))
            s.wfile.write(str(x+i).encode('utf-8')+"</td> ".encode('utf-8'))
            if not ((x+1) % 10): s.wfile.write("</tr>".encode('utf-8'))
        s.wfile.write("</table></body></html>".encode('utf-8'))
http.server.HTTPServer(("", 80),myHandler).serve_forever()
PYTHON_EOF
nohup python3 /usr/local/sbin/getprimes.py > /dev/null 2>&1 &
EOF

echo "🖥️ Creating frontend instance..."
gcloud compute instances create frontend \
    --zone $ZONE \
    --metadata-from-file startup-script=frontend.sh \
    --tags frontend \
    --machine-type e2-standard-2

echo "🛡️ Opening frontend firewall (Port 80)..."
gcloud compute firewall-rules create http2 --network default --allow=tcp:80 \
    --source-ranges 0.0.0.0/0 --target-tags frontend

echo "✅ Setup Complete!"
EXTERNAL_IP=$(gcloud compute instances describe frontend --zone $ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "-------------------------------------------------------"
echo "Public Frontend URL: http://$EXTERNAL_IP"
echo "Internal Load Balancer IP: $ILB_IP"
echo "-------------------------------------------------------"
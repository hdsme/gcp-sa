#!/bin/bash

set -e

echo "🚀 Start IAM Custom Roles Lab Automation..."

PROJECT_ID=$(gcloud config get-value project)
echo "Using project: $PROJECT_ID"

# 1. Set region
echo "👉 Setting region..."
gcloud config set compute/region us-west3

# 2. Create YAML role (editor)
echo "👉 Creating role-definition.yaml..."
cat <<EOF > role-definition.yaml
title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
EOF

echo "👉 Creating custom role: editor..."
gcloud iam roles create editor \
--project $PROJECT_ID \
--file role-definition.yaml

# 3. Create role using flags (viewer)
echo "👉 Creating custom role: viewer..."
gcloud iam roles create viewer \
--project $PROJECT_ID \
--title "Role Viewer" \
--description "Custom role description." \
--permissions compute.instances.get,compute.instances.list \
--stage ALPHA

# 4. List roles
echo "👉 Listing roles..."
gcloud iam roles list --project $PROJECT_ID

# 5. Update editor role (YAML)
echo "👉 Getting editor role definition..."
gcloud iam roles describe editor --project $PROJECT_ID > new-role-definition.yaml

echo "👉 Updating YAML with new permissions..."
cat <<EOF > new-role-definition.yaml
title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
- storage.buckets.get
- storage.buckets.list
EOF

echo "👉 Updating editor role..."
gcloud iam roles update editor \
--project $PROJECT_ID \
--file new-role-definition.yaml

# 6. Update viewer role (flags)
echo "👉 Updating viewer role (add permissions)..."
gcloud iam roles update viewer \
--project $PROJECT_ID \
--add-permissions storage.buckets.get,storage.buckets.list

# 7. Disable viewer role
echo "👉 Disabling viewer role..."
gcloud iam roles update viewer \
--project $PROJECT_ID \
--stage DISABLED

# 8. Delete viewer role
echo "👉 Deleting viewer role..."
gcloud iam roles delete viewer \
--project $PROJECT_ID --quiet

# 9. Restore viewer role
echo "👉 Restoring viewer role..."
gcloud iam roles undelete viewer \
--project $PROJECT_ID

echo "✅ DONE! Lab completed."
#!/bin/bash

set -e

echo "🚀 Start IAM Custom Roles Lab Automation..."

PROJECT_ID=$(gcloud config get-value project)
echo "Using project: $PROJECT_ID"

# Helper function: check role exists
role_exists() {
  gcloud iam roles describe "$1" --project "$PROJECT_ID" >/dev/null 2>&1
}

# 1. Set region
echo "👉 Setting region..."
gcloud config set compute/region us-west3

# 2. Prepare YAML (editor)
cat <<EOF > role-definition.yaml
title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
EOF

# 3. Create or Update editor role
echo "👉 Handling role: editor..."
if role_exists editor; then
  echo "⚠️ Role editor exists → updating..."
  gcloud iam roles update editor \
    --project $PROJECT_ID \
    --file role-definition.yaml
else
  echo "✅ Creating role editor..."
  gcloud iam roles create editor \
    --project $PROJECT_ID \
    --file role-definition.yaml
fi

# 4. Create or Update viewer role
echo "👉 Handling role: viewer..."
if role_exists viewer; then
  echo "⚠️ Role viewer exists → updating..."
  gcloud iam roles update viewer \
    --project $PROJECT_ID \
    --title "Role Viewer" \
    --description "Custom role description." \
    --permissions compute.instances.get,compute.instances.list \
    --stage ALPHA
else
  echo "✅ Creating role viewer..."
  gcloud iam roles create viewer \
    --project $PROJECT_ID \
    --title "Role Viewer" \
    --description "Custom role description." \
    --permissions compute.instances.get,compute.instances.list \
    --stage ALPHA
fi

# 5. List roles
echo "👉 Listing roles..."
gcloud iam roles list --project $PROJECT_ID

# 6. Update editor role (add storage permissions)
echo "👉 Updating editor role with storage permissions..."
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

gcloud iam roles update editor \
--project $PROJECT_ID \
--file new-role-definition.yaml

# 7. Update viewer role
echo "👉 Updating viewer role..."
gcloud iam roles update viewer \
--project $PROJECT_ID \
--add-permissions storage.buckets.get,storage.buckets.list || true

# 8. Disable viewer role
echo "👉 Disabling viewer role..."
gcloud iam roles update viewer \
--project $PROJECT_ID \
--stage DISABLED || true

# 9. Delete viewer role
echo "👉 Deleting viewer role..."
gcloud iam roles delete viewer \
--project $PROJECT_ID --quiet || true

# 10. Restore viewer role
echo "👉 Restoring viewer role..."
gcloud iam roles undelete viewer \
--project $PROJECT_ID || true

echo "✅ DONE! Lab completed without crash."
# IAM Custom Roles

<h2>📁 Steps</h2>

<ol>
<li>Open <b>Cloud Shell</b>.</li>
<li>Run the following command:</li>

```bash
#!/bin/bash

C0=$'\033[0m'
B=$'\033[1m'

R=$'\033[38;5;196m'
G=$'\033[38;5;46m'
Y=$'\033[38;5;226m'
C=$'\033[38;5;51m'
P=$'\033[38;5;213m'
W=$'\033[38;5;255m'

line() {
    printf "%b\n" "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C0}"
}

banner() {
    clear
    line
    printf "%b\n" "${G}${B}            IAM CUSTOM ROLE MANAGEMENT${C0}"
    line
    echo
}

step() {
    printf "%b\n" "${P}${B}▶ $1${C0}"
}

ok() {
    printf "%b\n\n" "${G}✔ $1${C0}"
}

banner

step "Generating role-definition.yaml"

cat > role-definition.yaml <<EOF
title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
EOF

ok "role-definition.yaml created"

step "Creating custom role: editor"

gcloud iam roles create editor \
    --project="$DEVSHELL_PROJECT_ID" \
    --file=role-definition.yaml

ok "Editor role created"

step "Creating custom role: viewer"

gcloud iam roles create viewer \
    --project="$DEVSHELL_PROJECT_ID" \
    --title="Role Viewer" \
    --description="Custom role description." \
    --permissions=compute.instances.get,compute.instances.list \
    --stage=ALPHA

ok "Viewer role created"

step "Generating updated role configuration"

cat > new-role-definition.yaml <<EOF
description: Edit access for App Versions
etag:
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
- storage.buckets.get
- storage.buckets.list
name: projects/$DEVSHELL_PROJECT_ID/roles/editor
stage: ALPHA
title: Role Editor
EOF

ok "Updated configuration ready"

step "Updating editor role"

gcloud iam roles update editor \
    --project="$DEVSHELL_PROJECT_ID" \
    --file=new-role-definition.yaml \
    --quiet

ok "Editor role updated"

step "Adding Storage permissions to viewer"

gcloud iam roles update viewer \
    --project="$DEVSHELL_PROJECT_ID" \
    --add-permissions=storage.buckets.get,storage.buckets.list

ok "Viewer permissions updated"

step "Disabling viewer role"

gcloud iam roles update viewer \
    --project="$DEVSHELL_PROJECT_ID" \
    --stage=DISABLED

ok "Viewer role disabled"

step "Deleting viewer role"

gcloud iam roles delete viewer \
    --project="$DEVSHELL_PROJECT_ID"

ok "Viewer role deleted"

step "Restoring viewer role"

gcloud iam roles undelete viewer \
    --project="$DEVSHELL_PROJECT_ID"

echo
line
printf "%b\n" "${G}${B}           ALL IAM ROLE TASKS COMPLETED${C0}"
line
echo
```

</ol>
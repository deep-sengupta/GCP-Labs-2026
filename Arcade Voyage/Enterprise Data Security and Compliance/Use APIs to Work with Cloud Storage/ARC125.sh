#!/bin/bash

# Color Theme
HEADER_COLOR=$'\033[38;5;39m'       # Neon Blue
STEP_COLOR=$'\033[38;5;87m'         # Aqua
SUCCESS_COLOR=$'\033[38;5;82m'      # Neon Green
ERROR_COLOR=$'\033[38;5;197m'       # Hot Pink
INFO_COLOR=$'\033[38;5;45m'         # Sky Blue
ACTION_COLOR=$'\033[38;5;220m'      # Amber
TEXT_COLOR=$'\033[38;5;255m'        # White
RESET=$'\033[0m'
BOLD=$'\033[1m'

clear

echo
echo "${HEADER_COLOR}${BOLD}🌍 CLOUD STORAGE API OPERATIONS${RESET}"
echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

# Function to display step messages
step() {
    echo "${STEP_COLOR}${BOLD}🚀 $1${RESET}"
}

success() {
    echo "${SUCCESS_COLOR}✔ $1${RESET}"
}

# Step 1: Create bucket1.json
step "Step 1 • Creating bucket1.json configuration..."
cat > bucket1.json <<EOF
{
   "name": "$DEVSHELL_PROJECT_ID-bucket-1",
   "location": "us",
   "storageClass": "multi_regional"
}
EOF
success "bucket1.json created successfully"

# Step 2: Create bucket1
echo
step "Step 2 • Creating first Cloud Storage bucket..."
curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" \
     --data-binary @bucket1.json \
     "https://storage.googleapis.com/storage/v1/b?project=$DEVSHELL_PROJECT_ID"
success "Bucket $DEVSHELL_PROJECT_ID-bucket-1 created successfully"

# Step 3: Create bucket2.json
echo
step "Step 3 • Creating bucket2.json configuration..."
cat > bucket2.json <<EOF
{
   "name": "$DEVSHELL_PROJECT_ID-bucket-2",
   "location": "us",
   "storageClass": "multi_regional"
}
EOF
success "bucket2.json created successfully"

# Step 4: Create bucket2
echo
step "Step 4 • Creating second Cloud Storage bucket..."
curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" \
     --data-binary @bucket2.json \
     "https://storage.googleapis.com/storage/v1/b?project=$DEVSHELL_PROJECT_ID"
success "Bucket $DEVSHELL_PROJECT_ID-bucket-2 created successfully"

# Step 5: Download the image file
echo
step "Step 5 • Downloading world.jpeg..."
curl -s -LO 
success "Image downloaded successfully"

# Step 6: Upload image file to bucket1
echo
step "Step 6 • Uploading image to first bucket..."
curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: image/jpeg" \
     --data-binary @world.jpeg \
     "https://storage.googleapis.com/upload/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1/o?uploadType=media&name=world.jpeg"
success "Image uploaded to bucket1 successfully"

# Step 7: Copy the image from bucket1 to bucket2
echo
step "Step 7 • Copying image to second bucket..."
curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" \
     --data '{"destination": "$DEVSHELL_PROJECT_ID-bucket-2"}' \
     "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1/o/world.jpeg/copyTo/b/$DEVSHELL_PROJECT_ID-bucket-2/o/world.jpeg"
success "Image copied to bucket2 successfully"

# Step 8: Set public access for the image
echo
step "Step 8 • Configuring public access..."
cat > public_access.json <<EOF
{
  "entity": "allUsers",
  "role": "READER"
}
EOF

curl -s -X POST --data-binary @public_access.json \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" \
     "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1/o/world.jpeg/acl"
success "Public access configured successfully"

echo
echo "${INFO_COLOR}${BOLD}⏸ Verify your lab progress up to TASK 4.${RESET}"
read -p "${ACTION_COLOR}Press any key to continue... ${RESET}" -n 1 -r
echo

# Step 9: Delete the image from bucket1
echo
step "Step 9 • Removing image from first bucket..."
curl -s -X DELETE -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1/o/world.jpeg"
success "Image deleted from bucket1 successfully"

# Step 10: Delete bucket1
echo
step "Step 10 • Deleting first bucket..."
curl -s -X DELETE -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     "https://storage.googleapis.com/storage/v1/b/$DEVSHELL_PROJECT_ID-bucket-1"
success "Bucket1 deleted successfully"

echo
echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${SUCCESS_COLOR}${BOLD}🎉 Cloud Storage API operations completed successfully!${RESET}"
echo
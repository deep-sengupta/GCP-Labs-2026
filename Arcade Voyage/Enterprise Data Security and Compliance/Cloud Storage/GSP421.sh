#!/bin/bash

HEADER_COLOR=$'\033[38;5;39m'       # Neon Blue
TITLE_COLOR=$'\033[38;5;51m'        # Bright Cyan
PROMPT_COLOR=$'\033[38;5;220m'      # Amber
ACTION_COLOR=$'\033[38;5;87m'       # Aqua
SUCCESS_COLOR=$'\033[38;5;82m'      # Neon Green
WARNING_COLOR=$'\033[38;5;197m'     # Hot Pink
LINK_COLOR=$'\033[38;5;45m'         # Sky Blue
TEXT_COLOR=$'\033[38;5;255m'        # White

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

echo
echo "${HEADER_COLOR}${BOLD_TEXT}☁️  CLOUD STORAGE OPERATIONS${RESET_FORMAT}"
echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

# Step 1: Creating Buckets
echo "${ACTION_COLOR}${BOLD_TEXT}🚀 Step 1 • Creating Cloud Storage Buckets${RESET_FORMAT}"
gsutil mb gs://$DEVSHELL_PROJECT_ID
gsutil mb gs://$DEVSHELL_PROJECT_ID-2
echo "${SUCCESS_COLOR}✔ Buckets created successfully${RESET_FORMAT}"

# Step 2: Downloading Images
echo
echo "${ACTION_COLOR}${BOLD_TEXT}📥 Step 2 • Downloading Demo Images${RESET_FORMAT}"
curl -# -LO raw.githubusercontent.com/GoogleCloudPlatform/cloud-storage-samples/main/sample-files/demo-image1.png
curl -# -LO raw.githubusercontent.com/GoogleCloudPlatform/cloud-storage-samples/main/sample-files/demo-image2.png
curl -# -LO raw.githubusercontent.com/GoogleCloudPlatform/cloud-storage-samples/main/sample-files/demo-image1-copy.png
echo "${SUCCESS_COLOR}✔ Images downloaded successfully${RESET_FORMAT}"

# Step 3: Uploading Images
echo
echo "${ACTION_COLOR}${BOLD_TEXT}☁️  Step 3 • Uploading Images to Cloud Storage${RESET_FORMAT}"
gsutil cp demo-image1.png gs://$DEVSHELL_PROJECT_ID/demo-image1.png
gsutil cp demo-image2.png gs://$DEVSHELL_PROJECT_ID/demo-image2.png
gsutil cp demo-image1-copy.png gs://$DEVSHELL_PROJECT_ID-2/demo-image1-copy.png
echo "${SUCCESS_COLOR}✔ Files uploaded successfully${RESET_FORMAT}"

# Cleanup
echo
echo "${ACTION_COLOR}${BOLD_TEXT}🧹 Cleanup${RESET_FORMAT}"
SCRIPT_NAME="cloud-storage-lab.sh"
if [ -f "$SCRIPT_NAME" ]; then
    rm -- "$SCRIPT_NAME"
    echo "${SUCCESS_COLOR}✔ Temporary files cleaned up${RESET_FORMAT}"
fi

echo
echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${SUCCESS_COLOR}${BOLD_TEXT}🎉 Lab completed successfully!${RESET_FORMAT}"
echo
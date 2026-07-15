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
echo "${HEADER_COLOR}${BOLD_TEXT}☁️  CLOUD STORAGE SETUP${RESET_FORMAT}"
echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

# Region selection with validation
while true; do
    read -p "${PROMPT_COLOR}${BOLD_TEXT}🌍 Enter your preferred GCP region (e.g., us-central1): ${RESET_FORMAT}" REGION

    if [ -z "$REGION" ]; then
        echo "${WARNING_COLOR}ℹ Using default region. For production, always specify a region.${RESET_FORMAT}"
        break
    elif [[ $REGION =~ ^[a-z]+-[a-z]+[0-9]+$ ]]; then
        echo "${SUCCESS_COLOR}✔ Valid region format detected${RESET_FORMAT}"
        break
    else
        echo "${WARNING_COLOR}⚠ Invalid region format. Please use format like 'us-central1'.${RESET_FORMAT}"
    fi
done

export REGION
gcloud config set compute/region $REGION
echo "${ACTION_COLOR}${BOLD_TEXT}⚙ Configuring default region: ${REGION}${RESET_FORMAT}"

echo

echo "${ACTION_COLOR}${BOLD_TEXT}🚀 Step 1 • Creating Cloud Storage bucket${RESET_FORMAT}"
gsutil mb gs://$DEVSHELL_PROJECT_ID
echo "${SUCCESS_COLOR}✔ Bucket created successfully${RESET_FORMAT}"

echo

echo "${ACTION_COLOR}${BOLD_TEXT}📥 Step 2 • Downloading sample image${RESET_FORMAT}"
curl -# https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg --output ada.jpg
echo "${SUCCESS_COLOR}✔ Image downloaded successfully${RESET_FORMAT}"

echo

echo "${ACTION_COLOR}${BOLD_TEXT}☁️ Step 3 • Uploading image to Cloud Storage${RESET_FORMAT}"
gsutil cp ada.jpg gs://$DEVSHELL_PROJECT_ID
echo "${SUCCESS_COLOR}✔ Image uploaded successfully${RESET_FORMAT}"

echo

echo "${ACTION_COLOR}${BOLD_TEXT}📤 Step 4 • Downloading image from bucket${RESET_FORMAT}"
gsutil cp -r gs://$DEVSHELL_PROJECT_ID/ada.jpg .
echo "${SUCCESS_COLOR}✔ Image downloaded successfully${RESET_FORMAT}"

echo

echo "${ACTION_COLOR}${BOLD_TEXT}📂 Step 5 • Creating folder structure${RESET_FORMAT}"
gsutil cp gs://$DEVSHELL_PROJECT_ID/ada.jpg gs://$DEVSHELL_PROJECT_ID/image-folder/
echo "${SUCCESS_COLOR}✔ Folder structure created${RESET_FORMAT}"

echo

echo "${ACTION_COLOR}${BOLD_TEXT}🌐 Step 6 • Setting public access permissions${RESET_FORMAT}"
gsutil acl ch -u AllUsers:R gs://$DEVSHELL_PROJECT_ID/ada.jpg
echo "${SUCCESS_COLOR}✔ Public access configured${RESET_FORMAT}"

echo
echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${SUCCESS_COLOR}${BOLD_TEXT}🎉 Cloud Storage setup completed successfully!${RESET_FORMAT}"
echo
#!/bin/bash

BLACK_TEXT=$'\033[38;5;240m'
RED_TEXT=$'\033[38;5;203m'
GREEN_TEXT=$'\033[38;5;84m'
YELLOW_TEXT=$'\033[38;5;227m'
BLUE_TEXT=$'\033[38;5;75m'
MAGENTA_TEXT=$'\033[38;5;141m'
CYAN_TEXT=$'\033[38;5;51m'
WHITE_TEXT=$'\033[38;5;255m'
TEAL=$'\033[38;5;44m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'
BLINK_TEXT=$'\033[5m'
NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'
REVERSE_TEXT=$'\033[7m'

clear

echo "${MAGENTA_TEXT}${BOLD_TEXT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                  DATAPLEX LAB AUTOMATION                    "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${RESET_FORMAT}"

read -p "$(echo -e "${YELLOW_TEXT}${BOLD_TEXT}➜ Enter REGION: ${RESET_FORMAT}")" REGION

echo
echo "${CYAN_TEXT}${BOLD_TEXT}Selected Region:${RESET_FORMAT} ${WHITE_TEXT}${REGION}${RESET_FORMAT}"
echo
echo "${GREEN_TEXT}${BOLD_TEXT}▶ Enabling Google Cloud APIs...${RESET_FORMAT}"

gcloud services enable dataplex.googleapis.com

gcloud services enable datacatalog.googleapis.com

echo "${BLUE_TEXT}${BOLD_TEXT}▶ Creating Dataplex Lake...${RESET_FORMAT}"

gcloud dataplex lakes create customer-info-lake \
  --location=$REGION \
  --display-name="Customer Info Lake"

echo "${BLUE_TEXT}${BOLD_TEXT}▶ Creating Raw Zone...${RESET_FORMAT}"

gcloud alpha dataplex zones create customer-raw-zone \
  --location=$REGION \
  --lake=customer-info-lake \
  --resource-location-type=SINGLE_REGION \
  --type=RAW \
  --display-name="Customer Raw Zone"

echo "${BLUE_TEXT}${BOLD_TEXT}▶ Creating Storage Asset...${RESET_FORMAT}"

gcloud dataplex assets create customer-online-sessions \
  --location=$REGION \
  --lake=customer-info-lake \
  --zone=customer-raw-zone \
  --resource-type=STORAGE_BUCKET \
  --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID-bucket \
  --display-name="Customer Online Sessions"

echo
echo "${YELLOW_TEXT}${BOLD_TEXT}OPEN THIS LINK:${RESET_FORMAT}"
echo "${WHITE_TEXT}${BOLD_TEXT}https://console.cloud.google.com/dataplex/secure?resourceName=projects%2F$DEVSHELL_PROJECT_ID%2Flocations%2F$REGION%2Flakes%2Fcustomer-info-lake&project=$DEVSHELL_PROJECT_ID${RESET_FORMAT}"

echo
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}                  LAB COMPLETED SUCCESSFULLY                 ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
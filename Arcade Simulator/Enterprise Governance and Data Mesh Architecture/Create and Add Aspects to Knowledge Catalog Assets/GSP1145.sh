#!/bin/bash

BLACK_TEXT=$'\033[38;5;240m'
RED_TEXT=$'\033[38;5;203m'
GREEN_TEXT=$'\033[38;5;84m'
YELLOW_TEXT=$'\033[38;5;227m'
BLUE_TEXT=$'\033[38;5;75m'
MAGENTA_TEXT=$'\033[38;5;141m'
CYAN_TEXT=$'\033[38;5;51m'
WHITE_TEXT=$'\033[38;5;255m'

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

RED='\033[38;5;203m'
GREEN='\033[38;5;84m'
BLUE='\033[38;5;75m'
YELLOW='\033[38;5;227m'
NC='\033[0m'

clear

echo "${MAGENTA_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${MAGENTA_TEXT}${BOLD_TEXT}            DATAPLEX AUTOMATION INITIALIZED              ${RESET_FORMAT}"
echo "${MAGENTA_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

function echo_info() {
    echo -e "${BLUE}${BOLD_TEXT}▶${NC} $1"
}

function echo_success() {
    echo -e "${GREEN}${BOLD_TEXT}✔${NC} $1"
}

function echo_warn() {
    echo -e "${YELLOW}${BOLD_TEXT}➜${NC} $1"
}

function echo_error() {
    echo -e "${RED}${BOLD_TEXT}✖${NC} $1"
}

read -p "Enter the region (e.g., us-east4): " REGION

PROJECT_ID=$(gcloud config get-value project)
if [[ -z "$PROJECT_ID" ]]; then
  echo_error "Unable to retrieve GCP project ID; ensure you're authenticated."
  exit 1
fi

LAKE_NAME="orders-lake"
LAKE_DISPLAY_NAME="Orders Lake"
ZONE_NAME="customer-curated-zone"
ZONE_DISPLAY_NAME="Customer Curated Zone"
ASSET_NAME="customer-details-dataset"
ASSET_DISPLAY_NAME="Customer Details Dataset"
ASPECT_TYPE_ID="protected-data-aspect"
ASPECT_TYPE_DISPLAY_NAME="Protected Data Aspect"
ASPECT_JSON_FILE="aspect_type.json"

echo_info "Project: $PROJECT_ID"
echo_info "Region: $REGION"

echo
echo "${CYAN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Creating Dataplex Lake${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"

gcloud dataplex lakes create $LAKE_NAME \
  --project=$PROJECT_ID --location=$REGION --display-name="$LAKE_DISPLAY_NAME"

echo_warn "Waiting for lake to become ACTIVE..."

ATT=0
while true; do
  STATE=$(gcloud dataplex lakes describe $LAKE_NAME --project=$PROJECT_ID --location=$REGION --format='value(state)' 2>/dev/null)
  if [[ "$STATE" == "ACTIVE" ]]; then
    echo_success "Lake is ACTIVE."
    break
  fi
  ((ATT++))
  [[ $ATT -ge 20 ]] && echo_error "Lake did not become ACTIVE in time." && exit 1
  echo_warn "Current state: $STATE. Retrying in 30 seconds..."
  sleep 30
done

echo
echo "${CYAN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Creating Curated Zone${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"

gcloud dataplex zones create $ZONE_NAME \
  --project=$PROJECT_ID --location=$REGION --lake=$LAKE_NAME \
  --display-name="$ZONE_DISPLAY_NAME" --type=CURATED --resource-location-type=SINGLE_REGION

echo_warn "Waiting for zone to become ACTIVE..."

ATT=0
while true; do
  STATE=$(gcloud dataplex zones describe $ZONE_NAME --project=$PROJECT_ID --lake=$LAKE_NAME --location=$REGION --format='value(state)' 2>/dev/null)
  if [[ "$STATE" == "ACTIVE" ]]; then
    echo_success "Zone is ACTIVE."
    break
  fi
  ((ATT++))
  [[ $ATT -ge 20 ]] && echo_error "Zone did not become ACTIVE in time." && exit 1
  echo_warn "Current state: $STATE. Retrying in 30 seconds..."
  sleep 30
done

echo
echo "${CYAN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}Attaching BigQuery Dataset${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"

gcloud dataplex assets create $ASSET_NAME \
  --project=$PROJECT_ID --location=$REGION --lake=$LAKE_NAME --zone=$ZONE_NAME \
  --display-name="$ASSET_DISPLAY_NAME" --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/$PROJECT_ID/datasets/customers --discovery-enabled

echo_success "Asset created."

echo
echo_info "Proceed to the UI to apply aspects to table columns."

echo
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}                LAB COMPLETED SUCCESSFULLY                ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
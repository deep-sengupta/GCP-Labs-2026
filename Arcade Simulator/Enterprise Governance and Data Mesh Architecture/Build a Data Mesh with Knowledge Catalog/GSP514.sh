#!/bin/bash

ORANGE_TEXT=$'\033[38;5;214m'
RED_TEXT=$'\033[38;5;203m'
GREEN_TEXT=$'\033[38;5;84m'
YELLOW_TEXT=$'\033[38;5;227m'
BLUE_TEXT=$'\033[38;5;75m'
PURPLE_TEXT=$'\033[38;5;141m'
CYAN_TEXT=$'\033[38;5;51m'
WHITE_TEXT=$'\033[38;5;15m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'
RESET_FORMAT=$'\033[0m'

clear

echo "${PURPLE_TEXT}${BOLD_TEXT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                 DATAPLEX KNOWLEDGE CATALOG LAB                 "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${RESET_FORMAT}"

echo "${CYAN_TEXT}${BOLD_TEXT}Activating required Google Cloud APIs...${RESET_FORMAT}"

gcloud services enable \
dataplex.googleapis.com \
datacatalog.googleapis.com \
dataproc.googleapis.com

echo "${GREEN_TEXT}${BOLD_TEXT}✓ APIs enabled successfully.${RESET_FORMAT}"
echo

export PROJECT_ID=$(gcloud config get-value project)

ZONE=$(gcloud config get-value compute/zone 2>/dev/null)

if [[ -z "$ZONE" ]]; then
  ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
fi

REGION=$(echo "$ZONE" | cut -d'-' -f1-2)

echo "${BLUE_TEXT}${BOLD_TEXT}Project ID : ${WHITE_TEXT}${PROJECT_ID}${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}Zone       : ${WHITE_TEXT}${ZONE}${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}Region     : ${WHITE_TEXT}${REGION}${RESET_FORMAT}"
echo

echo "${PURPLE_TEXT}${BOLD_TEXT}Creating Dataplex Lake...${RESET_FORMAT}"
gcloud dataplex lakes create sales-lake \
  --location=$REGION \
  --display-name="Sales Lake"

echo "${GREEN_TEXT}${BOLD_TEXT}✓ Sales Lake created.${RESET_FORMAT}"
echo

echo "${PURPLE_TEXT}${BOLD_TEXT}Creating Raw Customer Zone...${RESET_FORMAT}"
gcloud dataplex zones create raw-customer-zone \
  --lake=sales-lake \
  --location=$REGION \
  --display-name="Raw Customer Zone" \
  --type=RAW \
  --resource-location-type=SINGLE_REGION \
  --discovery-enabled \
  --discovery-schedule="0 * * * *"

echo "${GREEN_TEXT}${BOLD_TEXT}✓ Raw Customer Zone created.${RESET_FORMAT}"
echo

echo "${PURPLE_TEXT}${BOLD_TEXT}Creating Curated Customer Zone...${RESET_FORMAT}"

gcloud dataplex zones create curated-customer-zone \
  --lake=sales-lake \
  --location=$REGION \
  --display-name="Curated Customer Zone" \
  --type=CURATED \
  --resource-location-type=SINGLE_REGION \
  --discovery-enabled \
  --discovery-schedule="0 * * * *"

echo "${GREEN_TEXT}${BOLD_TEXT}✓ Curated Customer Zone created.${RESET_FORMAT}"
echo

echo "${ORANGE_TEXT}${BOLD_TEXT}Creating Dataplex Assets...${RESET_FORMAT}"

gcloud dataplex assets create customer-engagements \
  --lake=sales-lake \
  --zone=raw-customer-zone \
  --location=$REGION \
  --display-name="Customer Engagements" \
  --resource-type=STORAGE_BUCKET \
  --resource-name=projects/$PROJECT_ID/buckets/$PROJECT_ID-customer-online-sessions \
  --discovery-enabled

gcloud dataplex assets create customer-orders \
  --lake=sales-lake \
  --zone=curated-customer-zone \
  --location=$REGION \
  --display-name="Customer Orders" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/$PROJECT_ID/datasets/customer_orders \
  --discovery-enabled

echo "${GREEN_TEXT}${BOLD_TEXT}✓ Assets created successfully.${RESET_FORMAT}"
echo

echo "${CYAN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}                 COMPLETE TASK 2 MANUALLY                        ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

echo "${YELLOW_TEXT}${BOLD_TEXT}Knowledge Catalog:${RESET_FORMAT} https://console.cloud.google.com/dataplex?project=$(gcloud config get-value project)"
echo
echo "${WHITE_TEXT}${BOLD_TEXT}Aspect Type:${RESET_FORMAT} Protected Customer Data Aspect"
echo
echo "${WHITE_TEXT}${BOLD_TEXT}Field 1:${RESET_FORMAT} Raw Data Flag"
echo "${WHITE_TEXT}${BOLD_TEXT}Values:${RESET_FORMAT} Yes, No"
echo
echo "${WHITE_TEXT}${BOLD_TEXT}Field 2:${RESET_FORMAT} Protected Contact Information Flag"
echo "${WHITE_TEXT}${BOLD_TEXT}Values:${RESET_FORMAT} Yes, No"
echo
echo "${WHITE_TEXT}${BOLD_TEXT}Attach Aspect:${RESET_FORMAT} Raw Customer Zone"
echo
echo "${WHITE_TEXT}${BOLD_TEXT}Set Values:${RESET_FORMAT}"
echo "${GREEN_TEXT}Raw Data Flag = Yes${RESET_FORMAT}"
echo "${GREEN_TEXT}Protected Contact Information Flag = Yes${RESET_FORMAT}"
echo

read -p "${GREEN_TEXT}${BOLD_TEXT}Press Enter after completing Task 2... ${RESET_FORMAT}"

echo
read -p "${ORANGE_TEXT}${BOLD_TEXT}Enter User 2 Email: ${RESET_FORMAT}" USER_2

echo "${ORANGE_TEXT}${BOLD_TEXT}Applying IAM Policy Binding...${RESET_FORMAT}"

gcloud dataplex assets add-iam-policy-binding customer-engagements \
  --lake=sales-lake \
  --zone=raw-customer-zone \
  --location=$REGION \
  --member=user:$USER_2 \
  --role=roles/dataplex.dataWriter

echo "${GREEN_TEXT}${BOLD_TEXT}✓ IAM policy applied.${RESET_FORMAT}"
echo

echo "${BLUE_TEXT}${BOLD_TEXT}Generating Data Quality configuration...${RESET_FORMAT}"

cat > dq-customer-orders.yaml <<EOF
rules:
- nonNullExpectation: {}
  column: user_id
  dimension: COMPLETENESS
  threshold: 1

- nonNullExpectation: {}
  column: order_id
  dimension: COMPLETENESS
  threshold: 1

postScanActions:
  bigqueryExport:
    resultsTable: projects/$PROJECT_ID/datasets/orders_dq_dataset/tables/results
EOF

gsutil cp dq-customer-orders.yaml gs://$PROJECT_ID-dq-config/

echo "${GREEN_TEXT}${BOLD_TEXT}✓ YAML uploaded successfully.${RESET_FORMAT}"
echo

echo "${PURPLE_TEXT}${BOLD_TEXT}Creating Data Quality Scan...${RESET_FORMAT}"

gcloud dataplex datascans create data-quality \
customer-orders-data-quality-job \
--project=$PROJECT_ID \
--location=$REGION \
--data-source-resource="//bigquery.googleapis.com/projects/$PROJECT_ID/datasets/customer_orders/tables/ordered_items" \
--data-quality-spec-file="gs://$PROJECT_ID-dq-config/dq-customer-orders.yaml"

echo "${GREEN_TEXT}${BOLD_TEXT}✓ Data Quality Scan created.${RESET_FORMAT}"
echo

echo "${ORANGE_TEXT}${BOLD_TEXT}Running Data Quality Scan...${RESET_FORMAT}"

gcloud dataplex datascans run \
customer-orders-data-quality-job \
--location=$REGION

echo
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}              ALL AUTOMATED TASKS COMPLETED                      ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
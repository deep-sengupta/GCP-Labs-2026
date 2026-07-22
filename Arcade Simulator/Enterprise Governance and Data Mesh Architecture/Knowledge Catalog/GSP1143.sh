#!/bin/bash

set -e

PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

if [ -z "$REGION" ]; then
  REGION="us-central1"
fi

LAKE="sensors"
ZONE="temperature-raw-data"
ASSET="measurements"
BUCKET="${PROJECT_ID}"

echo "Enabling Dataplex API..."
gcloud services enable dataplex.googleapis.com

echo "Waiting for API..."
sleep 20

echo "Creating Lake..."
gcloud dataplex lakes create $LAKE \
    --location=$REGION \
    --display-name="sensors"

echo "Waiting for Lake..."
while true; do
    STATE=$(gcloud dataplex lakes describe $LAKE --location=$REGION --format="value(state)" 2>/dev/null || echo "")
    [[ "$STATE" == "ACTIVE" ]] && break
    sleep 15
done

echo "Creating Raw Zone..."
gcloud dataplex zones create $ZONE \
    --location=$REGION \
    --lake=$LAKE \
    --display-name="temperature raw data" \
    --type=RAW \
    --resource-location-type=SINGLE_REGION \
    --discovery-enabled

echo "Waiting for Zone..."
while true; do
    STATE=$(gcloud dataplex zones describe $ZONE \
        --lake=$LAKE \
        --location=$REGION \
        --format="value(state)" 2>/dev/null || echo "")
    [[ "$STATE" == "ACTIVE" ]] && break
    sleep 15
done

echo "Creating Bucket..."
gcloud storage buckets create gs://$BUCKET \
    --location=$REGION \
    --uniform-bucket-level-access >/dev/null 2>&1 || true

echo "Attaching Asset..."
gcloud dataplex assets create $ASSET \
    --location=$REGION \
    --lake=$LAKE \
    --zone=$ZONE \
    --display-name="measurements" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/${PROJECT_ID}/buckets/${BUCKET}"

echo "Waiting for Asset..."
while true; do
    STATE=$(gcloud dataplex assets describe $ASSET \
        --lake=$LAKE \
        --zone=$ZONE \
        --location=$REGION \
        --format="value(state)" 2>/dev/null || echo "")
    [[ "$STATE" == "ACTIVE" ]] && break
    sleep 15
done

echo "Deleting Asset..."
gcloud dataplex assets delete $ASSET \
    --lake=$LAKE \
    --zone=$ZONE \
    --location=$REGION \
    --quiet

echo "Waiting..."
sleep 20

echo "Deleting Zone..."
gcloud dataplex zones delete $ZONE \
    --lake=$LAKE \
    --location=$REGION \
    --quiet

echo "Waiting..."
sleep 20

echo "Deleting Lake..."
gcloud dataplex lakes delete $LAKE \
    --location=$REGION \
    --quiet

echo "Lab completed."
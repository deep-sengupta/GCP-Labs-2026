# User Authentication: Identity-Aware Proxy

<h2>📁 Steps</h2>

<ol>
<li>Open <b>Cloud Shell</b>.</li>
<li>Run the following command:</li><br>

> **Note:** Replace `PROJECT_ID`, `REGION` and `SERVICE` with the lab-mentioned details.

```bash
#!/bin/bash

set -euo pipefail

PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
STUDENT_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n 1)

REGION="LAB"
SERVICE="LAB"
BUCKET="gs://${PROJECT_ID}-bucket"
ZIP="user-authentication-with-iap.zip"
BASE_DIR="$HOME/user-authentication-with-iap"

IAP_SERVICE_AGENT="service-${PROJECT_NUMBER}@gcp-sa-iap.iam.gserviceaccount.com"
IAP_AUDIENCE="/projects/${PROJECT_NUMBER}/locations/${REGION}/services/${SERVICE}"

echo
echo "============================================================"
echo " User Authentication: Identity-Aware Proxy"
echo "============================================================"
echo
echo "PROJECT ID     : $PROJECT_ID"
echo "PROJECT NUMBER : $PROJECT_NUMBER"
echo "STUDENT EMAIL  : $STUDENT_EMAIL"
echo "REGION         : $REGION"
echo "SERVICE        : $SERVICE"
echo

echo "Enabling required APIs..."

gcloud services enable \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    iap.googleapis.com \
    iam.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --quiet

echo
echo "Downloading lab files..."

rm -rf "$BASE_DIR"
rm -f "$HOME/$ZIP"

gcloud storage cp "$BUCKET/$ZIP" "$HOME/$ZIP"

unzip -q "$HOME/$ZIP" -d "$HOME"

cd "$BASE_DIR"

echo
echo "============================================================"
echo " TASK 1 - Deploy Hello World"
echo "============================================================"
echo

cd "$BASE_DIR/1-HelloWorld"

gcloud run deploy "$SERVICE" \
    --source . \
    --region="$REGION" \
    --allow-unauthenticated \
    --quiet

SERVICE_URL=$(gcloud run services describe "$SERVICE" \
    --region="$REGION" \
    --format="value(status.url)")

echo
echo "Service URL:"
echo "$SERVICE_URL"
echo

echo "Waiting for service..."

gcloud run services describe "$SERVICE" \
    --region="$REGION" \
    --format="value(status.conditions[0].status)" >/dev/null

echo
echo "============================================================"
echo " TASK 1 - Enable IAP"
echo "============================================================"
echo

echo "Enabling IAP..."

gcloud run services update "$SERVICE" \
    --region="$REGION" \
    --iap \
    --quiet

echo
echo "Granting IAP service agent permission..."

gcloud run services add-iam-policy-binding "$SERVICE" \
    --region="$REGION" \
    --member="serviceAccount:${IAP_SERVICE_AGENT}" \
    --role="roles/run.invoker" \
    --quiet

echo
echo "Granting student account IAP access..."

gcloud iap web add-iam-policy-binding \
    --region="$REGION" \
    --resource-type=cloud-run \
    --service="$SERVICE" \
    --member="user:${STUDENT_EMAIL}" \
    --role="roles/iap.httpsResourceAccessor" \
    --quiet

echo
echo "Waiting for IAM propagation..."
sleep 10

echo
echo "============================================================"
echo " TASK 2 - Access User Identity"
echo "============================================================"
echo

cd "$BASE_DIR/2-HelloUser"

gcloud run deploy "$SERVICE" \
    --source . \
    --region="$REGION" \
    --quiet

SERVICE_URL=$(gcloud run services describe "$SERVICE" \
    --region="$REGION" \
    --format="value(status.url)")

echo
echo "Service URL:"
echo "$SERVICE_URL"
echo

echo "Waiting for deployment..."

sleep 10

echo
echo "============================================================"
echo " TASK 2 - Disable IAP"
echo "============================================================"
echo

gcloud run services update "$SERVICE" \
    --region="$REGION" \
    --no-iap \
    --quiet

gcloud run services add-iam-policy-binding "$SERVICE" \
    --region="$REGION" \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --quiet

echo
echo "IAP disabled."
echo

echo "Testing spoofed identity..."

curl -s \
    -H "X-Goog-Authenticated-User-Email: totally fake email" \
    "$SERVICE_URL" || true

echo
echo
echo "============================================================"
echo " TASK 3 - Cryptographic Verification"
echo "============================================================"
echo

cd "$BASE_DIR/3-HelloVerifiedUser"

echo "Using IAP audience:"
echo "$IAP_AUDIENCE"
echo

gcloud run deploy "$SERVICE" \
    --source . \
    --region="$REGION" \
    --set-env-vars="IAP_AUDIENCE=${IAP_AUDIENCE}" \
    --quiet

SERVICE_URL=$(gcloud run services describe "$SERVICE" \
    --region="$REGION" \
    --format="value(status.url)")

echo
echo "Service URL:"
echo "$SERVICE_URL"
echo

echo "Waiting for deployment..."

sleep 10

echo
echo "============================================================"
echo " TASK 4 - Re-enable IAP"
echo "============================================================"
echo

echo "Enabling IAP..."

gcloud run services update "$SERVICE" \
    --region="$REGION" \
    --iap \
    --quiet

echo
echo "Waiting for IAP configuration..."
sleep 10

echo
echo "Granting IAP service agent Cloud Run Invoker permission..."

gcloud run services add-iam-policy-binding "$SERVICE" \
    --region="$REGION" \
    --member="serviceAccount:${IAP_SERVICE_AGENT}" \
    --role="roles/run.invoker" \
    --quiet

echo
echo "Waiting for IAM propagation..."
sleep 15

echo
echo "Restoring student IAP access..."

gcloud iap web add-iam-policy-binding \
    --region="$REGION" \
    --resource-type=cloud-run \
    --service="$SERVICE" \
    --member="user:${STUDENT_EMAIL}" \
    --role="roles/iap.httpsResourceAccessor" \
    --quiet || true

echo
echo "Waiting for policy propagation..."
sleep 15

echo
echo "============================================================"
echo " FINAL VERIFICATION"
echo "============================================================"
echo

echo "Cloud Run service:"
gcloud run services describe "$SERVICE" \
    --region="$REGION" \
    --format="yaml(metadata.name,status.url,spec.template.metadata.annotations)"

echo
echo "IAP policy:"
gcloud iap web get-iam-policy \
    --region="$REGION" \
    --resource-type=cloud-run \
    --service="$SERVICE" \
    --format="yaml" || true

echo
echo "IAP JWT Audience:"
echo "$IAP_AUDIENCE"

echo
echo "Service URL:"
echo "$SERVICE_URL"

echo
echo "============================================================"
echo " LAB COMPLETED"
echo "============================================================"
echo
echo "Open the following URL:"
echo "$SERVICE_URL"
echo
echo "Student account:"
echo "$STUDENT_EMAIL"
echo
```

</ol>
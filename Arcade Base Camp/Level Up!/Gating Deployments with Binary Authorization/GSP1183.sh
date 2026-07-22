#!/bin/bash

BOLD_TEXT="\033[1m"
RESET_FORMAT="\033[0m"
BLUE_TEXT="\033[38;5;81m"
CYAN_TEXT="\033[38;5;51m"
GREEN_TEXT="\033[38;5;82m"
RED_TEXT="\033[38;5;203m"
WHITE_TEXT="\033[38;5;255m"
YELLOW_TEXT="\033[38;5;220m"
PURPLE_TEXT="\033[38;5;141m"
ORANGE_TEXT="\033[38;5;214m"

print_step() {
    echo -e "\n${PURPLE_TEXT}${BOLD_TEXT}╔══════════════════════════════════════════════════════════════╗${RESET_FORMAT}"
    echo -e "${PURPLE_TEXT}${BOLD_TEXT}║  ${WHITE_TEXT}▶ $1${PURPLE_TEXT}  ║${RESET_FORMAT}"
    echo -e "${PURPLE_TEXT}${BOLD_TEXT}╚══════════════════════════════════════════════════════════════╝${RESET_FORMAT}"
}

print_info() {
    echo -e "${CYAN_TEXT}◆ $1${RESET_FORMAT}"
}

print_success() {
    echo -e "${GREEN_TEXT}◆ $1${RESET_FORMAT}"
}

print_warning() {
    echo -e "${YELLOW_TEXT}◆ $1${RESET_FORMAT}"
}

print_error() {
    echo -e "${RED_TEXT}◆ $1${RESET_FORMAT}"
}

validate_project_id() {
  local project_id=$1
  if [[ -z "$project_id" ]]; then
    print_error "PROJECT_ID is not set. Please authenticate or set your active project."
    exit 1
  fi
}

set_zone_and_region() {
  ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
  REGION=$(gcloud config get-value compute/region 2>/dev/null)

  if [[ -z "$ZONE" ]]; then
    print_warning "Zone not detected in gcloud config."
    read -p "Enter your zone (e.g., us-central1-c): " ZONE
  fi

  if [[ -z "$REGION" ]]; then
    if [[ -n "$ZONE" ]]; then
      REGION=$(echo "$ZONE" | awk -F'-' '{print $1"-"$2}')
    else
      read -p "Enter your region (e.g., us-central1): " REGION
    fi
  fi

  export ZONE
  export REGION
  print_success "Context set -> Zone: $ZONE | Region: $REGION"
}

clear

echo -e "${BLUE_TEXT}${BOLD_TEXT}╔══════════════════════════════════════════════════════════════╗${RESET_FORMAT}"
echo -e "${BLUE_TEXT}${BOLD_TEXT}║${WHITE_TEXT}              Binary Authorization Lab Runner               ${BLUE_TEXT}${BOLD_TEXT}║${RESET_FORMAT}"
echo -e "${BLUE_TEXT}${BOLD_TEXT}╚══════════════════════════════════════════════════════════════╝${RESET_FORMAT}"

print_info "Initializing context variables..."

export PROJECT_ID=$(gcloud config get-value project)
validate_project_id "$PROJECT_ID"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

set_zone_and_region

print_step "Enabling Required Google Cloud Services"
print_info "This might take a moment if services are fresh..."
gcloud services enable \
  cloudkms.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  containerregistry.googleapis.com \
  artifactregistry.googleapis.com \
  containerscanning.googleapis.com \
  ondemandscanning.googleapis.com \
  binaryauthorization.googleapis.com

print_step "Creating Artifact Registry Repository"
gcloud artifacts repositories create artifact-scanning-repo \
  --repository-format=docker \
  --location=$REGION \
  --description="Docker repository"

print_info "Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

mkdir -p vuln-scan && cd vuln-scan

print_info "Writing application files..."
cat > ./Dockerfile << EOF
FROM python:3.8-alpine
WORKDIR /app
COPY . ./
RUN pip3 install Flask==2.1.0
RUN pip3 install gunicorn==20.1.0
RUN pip3 install Werkzeug==2.2.2
CMD exec gunicorn --bind :\$PORT --workers 1 --threads 8 main:app
EOF

cat > ./main.py << EOF
import os
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    name = os.environ.get("NAME", "Worlds")
    return "Hello {}!".format(name)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
EOF

print_info "Submitting build payload to Cloud Build..."
gcloud builds submit . -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image

print_step "Setting up Binary Authorization Attestor Structures"

cat > ./vulnz_note.json << EOM
{
  "attestation": {
    "hint": {
      "human_readable_name": "Container Vulnerabilities attestation authority"
    }
  }
}
EOM

NOTE_ID=vulnz_note

print_info "Registering Container Analysis Note..."
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    --data-binary @./vulnz_note.json \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=${NOTE_ID}"

ATTESTOR_ID=vulnz-attestor

print_info "Creating Container Binary Authorization Attestor..."
gcloud container binauthz attestors create $ATTESTOR_ID \
    --attestation-authority-note=$NOTE_ID \
    --attestation-authority-note-project=${PROJECT_ID}

BINAUTHZ_SA_EMAIL="service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"

cat > ./iam_request.json << EOM
{
  "resource": "projects/${PROJECT_ID}/notes/${NOTE_ID}",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${BINAUTHZ_SA_EMAIL}"
        ]
      }
    ]
  }
}
EOM

print_info "Applying IAM Occurrences Viewer Bindings..."
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    --data-binary @./iam_request.json \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${NOTE_ID}:setIamPolicy"

print_step "Provisioning Cloud KMS Asymmetric Keys"

KEY_LOCATION=global
KEYRING=binauthz-keys
KEY_NAME=codelab-key
KEY_VERSION=1

print_info "Creating Keyring..."
gcloud kms keyrings create "${KEYRING}" --location="${KEY_LOCATION}"

print_info "Generating asymmetric-signing cryptographic key..."
gcloud kms keys create "${KEY_NAME}" \
    --keyring="${KEYRING}" --location="${KEY_LOCATION}" \
    --purpose asymmetric-signing \
    --default-algorithm="ec-sign-p256-sha256"

print_info "Linking public key configuration to the Attestor..."
gcloud beta container binauthz attestors public-keys add \
    --attestor="${ATTESTOR_ID}" \
    --keyversion-project="${PROJECT_ID}" \
    --keyversion-location="${KEY_LOCATION}" \
    --keyversion-keyring="${KEYRING}" \
    --keyversion-key="${KEY_NAME}" \
    --keyversion="${KEY_VERSION}"

print_step "Generating Manual Cryptographic Attestation Baseline"

CONTAINER_PATH=${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image
DIGEST=$(gcloud container images describe ${CONTAINER_PATH}:latest --format='get(image_summary.digest)')

print_info "Signing image digest reference payload..."
gcloud beta container binauthz attestations sign-and-create \
    --artifact-url="${CONTAINER_PATH}@${DIGEST}" \
    --attestor="${ATTESTOR_ID}" \
    --attestor-project="${PROJECT_ID}" \
    --keyversion-project="${PROJECT_ID}" \
    --keyversion-location="${KEY_LOCATION}" \
    --keyversion-keyring="${KEYRING}" \
    --keyversion-key="${KEY_NAME}" \
    --keyversion="${KEY_VERSION}"

print_step "Bootstrapping GKE Cluster with Enforced Enforcement Mode"

gcloud beta container clusters create binauthz \
    --zone $ZONE \
    --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE

print_info "Authorizing Cloud Build execution permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
    --role="roles/container.developer"

print_step "Configuring Continuous Integration Automation Roles"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role roles/binaryauthorization.attestorsViewer

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role roles/cloudkms.signerVerifier

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --role roles/cloudkms.signerVerifier

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role roles/containeranalysis.notes.attacher

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/ondemandscanning.admin"

print_info "Building downstream custom attestation step builder..."
git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git
cd cloud-builders-community/binauthz-attestation
gcloud builds submit . --config cloudbuild.yaml
cd ../..
rm -rf cloud-builders-community

print_info "Assembling structural cloudbuild.yaml pipeline..."
cat > ./cloudbuild.yaml << EOF
steps:
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

- id: "retag"
  name: 'gcr.io/cloud-builders/docker'
  args: ['tag', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good']

- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good']

- id: "create-attestation"
  name: 'gcr.io/${PROJECT_ID}/binauthz-attestation:latest'
  args:
    - '--artifact-url'
    - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good'
    - '--attestor'
    - 'projects/${PROJECT_ID}/attestors/$ATTESTOR_ID'
    - '--keyversion'
    - 'projects/${PROJECT_ID}/locations/$KEY_LOCATION/keyRings/$KEYRING/cryptoKeys/$KEY_NAME/cryptoKeyVersions/$KEY_VERSION'

images:
  - ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good
EOF

print_info "Executing automated deployment pipeline run..."
gcloud builds submit

print_step "Updating Cluster Policies & Deploying Compliant Image"

cat > binauth_policy.yaml << EOM
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: REQUIRE_ATTESTATION
  requireAttestationsBy:
  - projects/${PROJECT_ID}/attestors/vulnz-attestor
globalPolicyEvaluationMode: ENABLE
clusterAdmissionRules:
  ${ZONE}.binauthz:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
    - projects/${PROJECT_ID}/attestors/vulnz-attestor
EOM

gcloud beta container binauthz policy import binauth_policy.yaml

CONTAINER_PATH=${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image
DIGEST=$(gcloud container images describe ${CONTAINER_PATH}:good --format='get(image_summary.digest)')

cat > deploy.yaml << EOM
apiVersion: v1
kind: Service
metadata:
  name: deb-httpd
spec:
  selector:
    app: deb-httpd
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deb-httpd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deb-httpd
  template:
    metadata:
      labels:
        app: deb-httpd
    spec:
      containers:
      - name: deb-httpd
        image: ${CONTAINER_PATH}@${DIGEST}
        ports:
        - containerPort: 8080
        env:
          - name: PORT
            value: "8080"
EOM

print_info "Applying signed deployment manifest to cluster..."
kubectl apply -f deploy.yaml

print_step "Executing Gatekeeping Verification on Unsigned Manifests"

docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:bad .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:bad

DIGEST=$(gcloud container images describe ${CONTAINER_PATH}:bad --format='get(image_summary.digest)')

cat > deploy.yaml << EOM
apiVersion: v1
kind: Service
metadata:
  name: deb-httpd
spec:
  selector:
    app: deb-httpd
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deb-httpd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deb-httpd
  template:
    metadata:
      labels:
        app: deb-httpd
    spec:
      containers:
      - name: deb-httpd
        image: ${CONTAINER_PATH}@${DIGEST}
        ports:
        - containerPort: 8080
        env:
          - name: PORT
            value: "8080"
EOM

print_info "Attempting deployment of unauthorized workspace context..."
kubectl apply -f deploy.yaml

echo
echo -e "${BLUE_TEXT}${BOLD_TEXT}╔══════════════════════════════════════════════════════════════╗${RESET_FORMAT}"
echo -e "${BLUE_TEXT}${BOLD_TEXT}║${WHITE_TEXT}               LAB COMPLETED SUCCESSFULLY!                 ${BLUE_TEXT}${BOLD_TEXT}║${RESET_FORMAT}"
echo -e "${BLUE_TEXT}${BOLD_TEXT}╚══════════════════════════════════════════════════════════════╝${RESET_FORMAT}"
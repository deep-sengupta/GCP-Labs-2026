#!/bin/bash

BLACK=$'\033[38;5;232m'
RED=$'\033[38;5;196m'
GREEN=$'\033[38;5;82m'
YELLOW=$'\033[38;5;220m'
BLUE=$'\033[38;5;75m'
MAGENTA=$'\033[38;5;213m'
CYAN=$'\033[38;5;51m'
WHITE=$'\033[38;5;15m'

BG_BLACK=$(tput setab 0)
BG_RED=$(tput setab 1)
BG_GREEN=$(tput setab 2)
BG_YELLOW=$(tput setab 3)
BG_BLUE=$(tput setab 4)
BG_MAGENTA=$(tput setab 5)
BG_CYAN=$(tput setab 6)
BG_WHITE=$(tput setab 7)

BOLD=$(tput bold)
RESET=$(tput sgr0)

banner() {
echo "${MAGENTA}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 SECURITY PIPELINE RUNNER                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo "${RESET}"
}

section() {
echo
echo "${CYAN}${BOLD}▶ $1${RESET}"
echo "${CYAN}──────────────────────────────────────────────────────────────${RESET}"
}

info() {
echo "${BLUE}• $1${RESET}"
}

success() {
echo "${GREEN}${BOLD}✓ $1${RESET}"
}

warn() {
echo "${YELLOW}${BOLD}⚠ $1${RESET}"
}

banner

section "Environment Configuration"
info "Retrieving project details..."
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)

echo "${YELLOW}Project ID:${RESET} ${WHITE}${BOLD}$PROJECT_ID${RESET}"
echo "${YELLOW}Project Number:${RESET} ${WHITE}${BOLD}$PROJECT_NUMBER${RESET}"
echo "${YELLOW}Zone:${RESET} ${WHITE}${BOLD}$ZONE${RESET}"
echo "${YELLOW}Region:${RESET} ${WHITE}${BOLD}$REGION${RESET}"
echo

section "Enabling Services"
info "Enabling required Google Cloud services..."
gcloud services enable 
cloudkms.googleapis.com 
run.googleapis.com 
cloudbuild.googleapis.com 
container.googleapis.com 
containerregistry.googleapis.com 
artifactregistry.googleapis.com 
containerscanning.googleapis.com 
ondemandscanning.googleapis.com 
binaryauthorization.googleapis.com
success "Services enabled successfully!"
echo

section "Application Setup"
info "Setting up sample application..."
mkdir sample-app && cd sample-app
gcloud storage cp gs://spls/gsp521/* .
success "Sample application setup complete!"
echo

section "Artifact Registry Configuration"
info "Creating artifact repositories..."
gcloud artifacts repositories create artifact-scanning-repo 
--repository-format=docker 
--location=$REGION 
--description="Scanning repository"

gcloud artifacts repositories create artifact-prod-repo 
--repository-format=docker 
--location=$REGION 
--description="Production repository"

gcloud auth configure-docker $REGION-docker.pkg.dev
success "Artifact Registry setup complete!"
echo

section "IAM Permissions"
info "Configuring IAM permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} 
--member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" 
--role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} 
--member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" 
--role="roles/ondemandscanning.admin"
success "IAM permissions configured!"
echo

section "Initial Build"
info "Creating initial cloudbuild.yaml..."
cat > cloudbuild.yaml <<EOF
steps:

* id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

* id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image']

images:

* ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image
  EOF

info "Submitting initial build..."
gcloud builds submit
success "Initial build completed!"
echo

section "Binary Authorization Setup"
info "Creating vulnerability note..."
cat > ./vulnerability_note.json <<EOM
{
"attestation": {
"hint": {
"human_readable_name": "Container Vulnerabilities attestation authority"
}
}
}
EOM

NOTE_ID=vulnerability_note
curl -X POST 
-H "Content-Type: application/json" 
-H "Authorization: Bearer $(gcloud auth print-access-token)" 
--data-binary @./vulnerability_note.json 
"https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=${NOTE_ID}"
success "Vulnerability note created!"

info "Creating attestor..."
ATTESTOR_ID=vulnerability-attestor
gcloud container binauthz attestors create $ATTESTOR_ID 
--attestation-authority-note=$NOTE_ID 
--attestation-authority-note-project=${PROJECT_ID}
success "Attestor created!"

info "Configuring IAM permissions for attestor..."
BINAUTHZ_SA_EMAIL="service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
cat > ./iam_request.json <<EOM
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

curl -X POST 
-H "Content-Type: application/json" 
-H "Authorization: Bearer $(gcloud auth print-access-token)" 
--data-binary @./iam_request.json 
"https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${NOTE_ID}:setIamPolicy"
success "IAM permissions configured!"
echo

section "KMS Key Setup"
info "Creating KMS keyring and key..."
KEY_LOCATION=global
KEYRING=binauthz-keys
KEY_NAME=lab-key
KEY_VERSION=1

gcloud kms keyrings create "${KEYRING}" --location="${KEY_LOCATION}"

gcloud kms keys create "${KEY_NAME}" 
--keyring="${KEYRING}" --location="${KEY_LOCATION}" 
--purpose asymmetric-signing 
--default-algorithm="ec-sign-p256-sha256"

gcloud beta container binauthz attestors public-keys add 
--attestor="${ATTESTOR_ID}" 
--keyversion-project="${PROJECT_ID}" 
--keyversion-location="${KEY_LOCATION}" 
--keyversion-keyring="${KEYRING}" 
--keyversion-key="${KEY_NAME}" 
--keyversion="${KEY_VERSION}"
success "KMS key setup complete!"
echo

section "Policy Configuration"
info "Configuring Binary Authorization policy..."
cat > my_policy.yaml <<EOM
defaultAdmissionRule:
enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
evaluationMode: REQUIRE_ATTESTATION
requireAttestationsBy:
- projects/${PROJECT_ID}/attestors/vulnerability-attestor
globalPolicyEvaluationMode: ENABLE
name: projects/${PROJECT_ID}/policy
EOM

gcloud container binauthz policy import my_policy.yaml
success "Policy configured successfully!"
echo

section "Additional IAM Permissions"
info "Configuring additional permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} 
--member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com 
--role roles/binaryauthorization.attestorsViewer

gcloud projects add-iam-policy-binding ${PROJECT_ID} 
--member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com 
--role roles/cloudkms.signerVerifier

gcloud projects add-iam-policy-binding ${PROJECT_ID} 
--member serviceAccount:${PROJECT_NUMBER}[-compute@developer.gserviceaccount.com](mailto:-compute@developer.gserviceaccount.com) 
--role roles/cloudkms.signerVerifier

gcloud projects add-iam-policy-binding ${PROJECT_ID} 
--member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com 
--role roles/containeranalysis.notes.attacher
success "Additional permissions configured!"
echo

section "Build Attestation Setup"
info "Setting up build attestation..."
git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git
cd cloud-builders-community/binauthz-attestation
gcloud builds submit . --config cloudbuild.yaml
cd ../..
rm -rf cloud-builders-community
success "Build attestation setup complete!"
echo

section "Final Build Pipeline"
info "Creating final build pipeline..."
cat <<EOF > cloudbuild.yaml
steps:

* id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest', '.']
  waitFor: ['-']

* id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest']

* id: scan
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:

  * '-c'
  * |
    (gcloud artifacts docker images scan \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest \
    --location us \
    --format="value(response.scan)") > /workspace/scan_id.txt

* id: severity check
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:

  * '-c'
  * |
    gcloud artifacts docker images list-vulnerabilities $(cat /workspace/scan_id.txt) \
    --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq CRITICAL; \
    then echo "Failed vulnerability check for CRITICAL level" && exit 1; else echo \
    "No CRITICAL vulnerability found, congrats !" && exit 0; fi

* id: 'create-attestation'
  name: 'gcr.io/${PROJECT_ID}/binauthz-attestation:latest'
  args:

  * '--artifact-url'
  * '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest'
  * '--attestor'
  * 'projects/${PROJECT_ID}/attestors/vulnerability-attestor'
  * '--keyversion'
  * 'projects/${PROJECT_ID}/locations/global/keyRings/binauthz-keys/cryptoKeys/lab-key/cryptoKeyVersions/1'

* id: "push-to-prod"
  name: 'gcr.io/cloud-builders/docker'
  args:

  * 'tag'
  * '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest'
  * '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-prod-repo/sample-image:latest'

* id: "push-to-prod-final"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-prod-repo/sample-image:latest']

* id: 'deploy-to-cloud-run'
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:

  * '-c'
  * |
    gcloud run deploy auth-service --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest 
    --binary-authorization=default --region=$REGION --allow-unauthenticated

images:

* ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest
  EOF

info "Running final build pipeline..."
gcloud builds submit
success "Final build pipeline completed!"
echo

section "Application Update"
info "Updating application dependencies..."
cat > ./Dockerfile <<EOF
FROM python:3.8-alpine

WORKDIR /app
COPY . ./

RUN pip3 install Flask==3.0.3
RUN pip3 install gunicorn==23.0.0
RUN pip3 install Werkzeug==3.0.4

CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 main:app
EOF

gcloud builds submit
success "Application updated successfully!"
echo

section "Final Configuration"
info "Configuring Cloud Run permissions..."
gcloud beta run services add-iam-policy-binding --region=$REGION --member=allUsers --role=roles/run.invoker auth-service
success "Cloud Run permissions configured!"
echo

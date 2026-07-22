#!/bin/bash

set -e

PURPLE='\033[38;5;141m'
SKY='\033[38;5;117m'
CYAN='\033[38;5;51m'
GREEN='\033[38;5;84m'
YELLOW='\033[38;5;227m'
ORANGE='\033[38;5;214m'
RED='\033[38;5;203m'
WHITE='\033[38;5;255m'
BOLD='\033[1m'
RESET='\033[0m'

PURPLE_TEXT="${PURPLE}${BOLD}"
SKY_TEXT="${SKY}${BOLD}"
CYAN_TEXT="${CYAN}${BOLD}"
GREEN_TEXT="${GREEN}${BOLD}"
YELLOW_TEXT="${YELLOW}${BOLD}"
ORANGE_TEXT="${ORANGE}${BOLD}"
RED_TEXT="${RED}${BOLD}"
WHITE_TEXT="${WHITE}${BOLD}"
RESET_FORMAT="${RESET}"

TOTAL_PHASES=5
START_TIME=$(date +%s)

banner() {
  printf "\n${PURPLE_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}\n"
  printf "${WHITE_TEXT}  [%s/%s] %s${RESET_FORMAT}\n" "$1" "$TOTAL_PHASES" "$2"
  printf "${PURPLE_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}\n"
}

success() {
  printf "${GREEN_TEXT}✔ %s${RESET_FORMAT}\n" "$1"
}

info() {
  printf "${CYAN_TEXT}➜ %s${RESET_FORMAT}\n" "$1"
}

warn() {
  printf "${ORANGE_TEXT}➜ %s${RESET_FORMAT}\n" "$1"
}

elapsed_since_start() {
  local now=$(date +%s)
  echo $((now - START_TIME))
}

clear

banner "1" "Detecting Project Environment"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    warn "Could not auto-detect Project ID. Make sure you are in Cloud Shell."
    exit 1
fi

ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
if [ -z "$ZONE" ]; then
    ZONE="us-central1-a"
fi

REGION=$(gcloud config get-value compute/region 2>/dev/null)
if [ -z "$REGION" ]; then
    REGION="${ZONE%-*}"
fi

success "Project ID : ${WHITE}$PROJECT_ID${RESET}"
success "Region     : ${WHITE}$REGION${RESET}"
success "Zone       : ${WHITE}$ZONE${RESET}"

banner "2" "Installing Terraform & Enabling Gemini API"

cat << 'EOF' > ~/.customize_environment
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
EOF

bash ~/.customize_environment
success "Terraform installed: $(terraform --version | head -n1)"

gcloud services enable cloudaicompanion.googleapis.com || warn "Gemini API could not be enabled"
success "Gemini for Google Cloud API enabled"

banner "3" "Provisioning with Local Backend"

cat << EOF > main.tf
provider "google" {
  project = "${PROJECT_ID}"
  region  = "${REGION}"
  zone    = "${ZONE}"
}

resource "google_storage_bucket" "test-bucket-for-state" {
  name                        = "${PROJECT_ID}"
  location                    = "US"
  uniform_bucket_level_access = true

  labels = {
    "key" = "value"
  }
}

terraform {
  backend "local" {
    path = "terraform/state/terraform.tfstate"
  }
}
EOF

terraform init
terraform apply -auto-approve
success "Local backend initialized and bucket provisioned ($(elapsed_since_start)s)"

banner "4" "Migrating State to GCS Backend"

cat << EOF > main.tf
provider "google" {
  project = "${PROJECT_ID}"
  region  = "${REGION}"
  zone    = "${ZONE}"
}

resource "google_storage_bucket" "test-bucket-for-state" {
  name                        = "${PROJECT_ID}"
  location                    = "US"
  uniform_bucket_level_access = true

  labels = {
    "key" = "value"
  }
}

terraform {
  backend "gcs" {
    bucket = "${PROJECT_ID}"
    prefix = "terraform/state"
  }
}
EOF

terraform init -migrate-state -force-copy
success "State migrated to gs://${PROJECT_ID}/terraform/state ($(elapsed_since_start)s)"

banner "5" "Refreshing State & Importing Instance"

info "Refreshing Terraform state"
terraform refresh

info "Creating unmanaged Compute Engine instance"
gcloud compute instances create sample-instance \
    --zone="${ZONE}" \
    --machine-type="e2-micro" \
    --image-family="debian-11" \
    --image-project="debian-cloud" \
    --quiet

success "Instance sample-instance created"

info "Updating Terraform configuration"

cat << EOF >> main.tf

resource "google_compute_instance" "import-instance" {
  name         = "sample-instance"
  machine_type = "e2-micro"
  zone         = "${ZONE}"

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
  }
}
EOF

info "Importing instance into Terraform state"
terraform import google_compute_instance.import-instance projects/${PROJECT_ID}/zones/${ZONE}/instances/sample-instance

success "Instance imported"

info "Synchronizing configuration"
terraform plan
terraform apply -auto-approve

success "Configuration synchronized ($(elapsed_since_start)s)"

echo
echo "${GREEN_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${GREEN_TEXT}                    LAB COMPLETED SUCCESSFULLY                      ${RESET_FORMAT}"
echo "${GREEN_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
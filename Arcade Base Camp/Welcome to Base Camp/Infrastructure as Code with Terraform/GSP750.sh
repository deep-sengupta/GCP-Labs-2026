#!/bin/bash

BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[38;5;203m'
GREEN_TEXT=$'\033[38;5;84m'
YELLOW_TEXT=$'\033[38;5;227m'
BLUE_TEXT=$'\033[38;5;75m'
MAGENTA_TEXT=$'\033[38;5;141m'
CYAN_TEXT=$'\033[38;5;51m'
WHITE_TEXT=$'\033[38;5;255m'
TEAL_TEXT=$'\033[38;5;44m'
PURPLE_TEXT=$'\033[38;5;135m'
GOLD_TEXT=$'\033[38;5;214m'
LIME_TEXT=$'\033[38;5;118m'
MAROON_TEXT=$'\033[38;5;167m'
NAVY_TEXT=$'\033[38;5;69m'

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'
BLINK_TEXT=$'\033[5m'
NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'
REVERSE_TEXT=$'\033[7m'

clear

echo -e "${PURPLE_TEXT}${BOLD_TEXT}╔══════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE_TEXT}${BOLD_TEXT}║        TERRAFORM ENVIRONMENT SETUP          ║${NC}"
echo -e "${PURPLE_TEXT}${BOLD_TEXT}╚══════════════════════════════════════════════╝${NC}"

echo -e "${YELLOW_TEXT}${BOLD_TEXT}⟳ Configuring Project Settings${NC}"
export REGION=${ZONE%-*}
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${GREEN_TEXT}${BOLD_TEXT}✔ Project ID: ${WHITE_TEXT}$PROJECT_ID${NC}"
echo -e "${GREEN_TEXT}${BOLD_TEXT}✔ Region: ${WHITE_TEXT}$REGION${NC}"
echo -e "${GREEN_TEXT}${BOLD_TEXT}✔ Zone: ${WHITE_TEXT}$ZONE${NC}"
echo

cat <<'EOF' > ~/.customize_environment
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
EOF
bash ~/.customize_environment

echo -e "${CYAN_TEXT}${BOLD_TEXT}◆ Phase 1: Deploying Network Infrastructure${NC}"
cat > main.tf <<EOF
terraform {
required_providers {
google = {
source = "hashicorp/google"
}
}
}
provider "google" {
version = "3.5.0"
project = "$PROJECT_ID"
region  = "$REGION"
zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
name = "terraform-network"
}
EOF

terraform init
terraform apply -auto-approve

echo -e "\n${CYAN_TEXT}${BOLD_TEXT}◆ Phase 2: Deploying Basic VM Instance${NC}"
cat > main.tf <<EOF
terraform {
required_providers {
google = {
source = "hashicorp/google"
}
}
}
provider "google" {
version = "3.5.0"
project = "$PROJECT_ID"
region  = "$REGION"
zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
name = "terraform-network"
}
resource "google_compute_instance" "vm_instance" {
name         = "terraform-instance"
machine_type = "e2-micro"
boot_disk {
initialize_params {
image = "debian-cloud/debian-12"
}
}
network_interface {
network = google_compute_network.vpc_network.name
access_config {}
}
}
EOF

terraform apply -auto-approve

echo -e "\n${CYAN_TEXT}${BOLD_TEXT}◆ Phase 3: Adding Tags to VM${NC}"
cat > main.tf <<EOF
terraform {
required_providers {
google = {
source = "hashicorp/google"
}
}
}
provider "google" {
version = "3.5.0"
project = "$PROJECT_ID"
region  = "$REGION"
zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
name = "terraform-network"
}
resource "google_compute_instance" "vm_instance" {
name         = "terraform-instance"
machine_type = "e2-micro"
tags         = ["web", "dev"]
boot_disk {
initialize_params {
image = "debian-cloud/debian-12"
}
}
network_interface {
network = google_compute_network.vpc_network.name
access_config {}
}
}
EOF

terraform apply -auto-approve

echo -e "\n${CYAN_TEXT}${BOLD_TEXT}◆ Phase 4: Switching to COS Image${NC}"
cat > main.tf <<EOF
terraform {
required_providers {
google = {
source = "hashicorp/google"
}
}
}
provider "google" {
version = "3.5.0"
project = "$PROJECT_ID"
region  = "$REGION"
zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
name = "terraform-network"
}
resource "google_compute_instance" "vm_instance" {
name         = "terraform-instance"
machine_type = "e2-micro"
tags         = ["web", "dev"]
boot_disk {
initialize_params {
image = "cos-cloud/cos-stable"
}
}
network_interface {
network = google_compute_network.vpc_network.name
access_config {}
}
}
EOF

terraform apply -auto-approve

echo -e "\n${CYAN_TEXT}${BOLD_TEXT}◆ Phase 5: Configuring Static IP${NC}"
cat > main.tf <<EOF
terraform {
required_providers {
google = {
source = "hashicorp/google"
}
}
}
provider "google" {
version = "3.5.0"
project = "$PROJECT_ID"
region  = "$REGION"
zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
name = "terraform-network"
}
resource "google_compute_instance" "vm_instance" {
name         = "terraform-instance"
machine_type = "e2-micro"
tags         = ["web", "dev"]
boot_disk {
initialize_params {
image = "cos-cloud/cos-stable"
}
}
network_interface {
network = google_compute_network.vpc_network.self_link
access_config {
nat_ip = google_compute_address.vm_static_ip.address
}
}
}
resource "google_compute_address" "vm_static_ip" {
name = "terraform-static-ip"
}
EOF

terraform plan -out static_ip
terraform apply "static_ip"

echo -e "\n${CYAN_TEXT}${BOLD_TEXT}◆ Phase 6: Deploying Storage Bucket${NC}"
cat > main.tf <<EOF
terraform {
required_providers {
google = {
source = "hashicorp/google"
}
}
}
provider "google" {
version = "3.5.0"
project = "$PROJECT_ID"
region  = "$REGION"
zone    = "$ZONE"
}
resource "google_compute_network" "vpc_network" {
name = "terraform-network"
}
resource "google_compute_instance" "vm_instance" {
name         = "terraform-instance"
machine_type = "e2-micro"
tags         = ["web", "dev"]
boot_disk {
initialize_params {
image = "cos-cloud/cos-stable"
}
}
network_interface {
network = google_compute_network.vpc_network.self_link
access_config {
nat_ip = google_compute_address.vm_static_ip.address
}
}
}
resource "google_compute_address" "vm_static_ip" {
name = "terraform-static-ip"
}
resource "google_storage_bucket" "example_bucket" {
name     = "$PROJECT_ID"
location = "US"
website {
main_page_suffix = "index.html"
not_found_page   = "404.html"
}
}
resource "google_compute_instance" "another_instance" {
depends_on   = [google_storage_bucket.example_bucket]
name         = "terraform-instance-2"
machine_type = "e2-micro"
boot_disk {
initialize_params {
image = "cos-cloud/cos-stable"
}
}
network_interface {
network = google_compute_network.vpc_network.self_link
access_config {}
}
}
EOF

terraform plan
terraform apply -auto-approve

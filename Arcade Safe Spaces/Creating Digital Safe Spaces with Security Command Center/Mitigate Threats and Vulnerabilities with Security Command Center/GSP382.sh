#!/bin/bash

set -u

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_DIM=$'\033[2m'
C_RED=$'\033[38;5;203m'
C_ORANGE=$'\033[38;5;214m'
C_YELLOW=$'\033[38;5;227m'
C_GREEN=$'\033[38;5;84m'
C_CYAN=$'\033[38;5;51m'
C_BLUE=$'\033[38;5;75m'
C_PURPLE=$'\033[38;5;141m'
C_WHITE=$'\033[38;5;15m'

title() {
  printf "\n%s%s%s\n" "$C_PURPLE" "$C_BOLD" "$1"
  printf "%s\n" "${C_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
}

info() {
  printf "%s%s%s\n" "$C_CYAN" "$C_BOLD" "$1$C_RESET"
}

step() {
  printf "%s%s▶ %s%s\n" "$C_YELLOW" "$C_BOLD" "$1" "$C_RESET"
}

ok() {
  printf "%s%s✓ %s%s\n" "$C_GREEN" "$C_BOLD" "$1" "$C_RESET"
}

warn() {
  printf "%s%s⚠ %s%s\n" "$C_ORANGE" "$C_BOLD" "$1" "$C_RESET"
}

fail() {
  printf "%s%s✗ %s%s\n" "$C_RED" "$C_BOLD" "$1" "$C_RESET"
}

clear

title "Security Command Center Automation"

info "Creating mute rules for Security Command Center findings..."

gcloud scc muteconfigs create muting-flow-log-findings \
  --project="$DEVSHELL_PROJECT_ID" \
  --location=global \
  --description="Rule for muting VPC Flow Logs" \
  --filter='category="FLOW_LOGS_DISABLED"' \
  --type=STATIC

gcloud scc muteconfigs create muting-audit-logging-findings \
  --project="$DEVSHELL_PROJECT_ID" \
  --location=global \
  --description="Rule for muting audit logs" \
  --filter='category="AUDIT_LOGGING_DISABLED"' \
  --type=STATIC

gcloud scc muteconfigs create muting-admin-sa-findings \
  --project="$DEVSHELL_PROJECT_ID" \
  --location=global \
  --description="Rule for muting admin service account findings" \
  --filter='category="ADMIN_SERVICE_ACCOUNT"' \
  --type=STATIC

printf "\n"
printf "%s%s%s\n" "$C_GREEN" "$C_BOLD" "======================================================="
printf "%s%s%s\n" "$C_GREEN" "$C_BOLD" "                   CHECK SCORE FOR TASK 2              "
printf "%s%s%s\n" "$C_GREEN" "$C_BOLD" "======================================================="
printf "\n"

step "Refreshing firewall rules"

gcloud compute firewall-rules delete default-allow-rdp --quiet || true

step "Creating updated RDP firewall rule"
gcloud compute firewall-rules create default-allow-rdp \
  --source-ranges=35.235.240.0/20 \
  --allow=tcp:3389 \
  --description="Allow RDP traffic from 35.235.240.0/20" \
  --priority=65534

step "Deleting default SSH firewall rule"
gcloud compute firewall-rules delete default-allow-ssh --quiet || true

step "Creating updated SSH firewall rule"
gcloud compute firewall-rules create default-allow-ssh \
  --source-ranges=35.235.240.0/20 \
  --allow=tcp:22 \
  --description="Allow SSH traffic from 35.235.240.0/20" \
  --priority=65534

step "Fetching VM zone information"
export ZONE="$(gcloud compute project-info describe --format='value(commonInstanceMetadata.items[google-compute-default-zone])')"

printf "\n%s%s%s%s%s\n" "$C_BLUE" "$C_BOLD" "OPEN THIS LINK: " "$C_WHITE" "https://console.cloud.google.com/compute/instancesEdit/zones/$ZONE/instances/cls-vm?project=$DEVSHELL_PROJECT_ID$C_RESET"

read -p "$(printf "%s%sHave you followed the steps (Y/N)? %s" "$C_RED" "$C_BOLD" "$C_RESET")" response
if [[ "$response" =~ ^[Yy]$ ]]; then
  ok "Great! Let's proceed."
else
  fail "Please follow the steps before continuing."
fi

printf "\n"

step "Setting up environment variables"
export ZONE="$(gcloud compute project-info describe --format='value(commonInstanceMetadata.items[google-compute-default-zone])')"
export REGION="$(echo "$ZONE" | cut -d '-' -f 1-2)"
export VM_EXT_IP="$(gcloud compute instances describe cls-vm --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"

step "Creating Cloud Storage bucket"
gsutil mb -p "$DEVSHELL_PROJECT_ID" -c STANDARD -l "$REGION" -b on "gs://scc-export-bucket-$DEVSHELL_PROJECT_ID"

step "Disabling uniform bucket-level access"
gsutil uniformbucketlevelaccess set off "gs://scc-export-bucket-$DEVSHELL_PROJECT_ID"

step "Downloading findings.jsonl"
curl -LO https://raw.githubusercontent.com/deep-sengupta/GCP-Labs-2026/refs/heads/master/Arcade%20Safe%20Spaces/Creating%20Digital%20Safe%20Spaces%20with%20Security%20Command%20Center/Mitigate%20Threats%20and%20Vulnerabilities%20with%20Security%20Command%20Center/findings.jsonl

step "Uploading findings.jsonl to the bucket"
gsutil cp findings.jsonl "gs://scc-export-bucket-$DEVSHELL_PROJECT_ID"

step "Opening scan configuration link"
printf "\n%s%s%s%s\n" "$C_CYAN" "$C_BOLD" "OPEN THIS LINK: " "$C_WHITE"
printf "%s\n" "https://console.cloud.google.com/security/web-scanner/scanConfigs/edit?project=$DEVSHELL_PROJECT_ID$C_RESET"

printf "%s%s%s%s\n" "$C_YELLOW" "$C_BOLD" "COPY THIS: " "$C_GREEN"
printf "%s\n" "http://$VM_EXT_IP:8080$C_RESET"

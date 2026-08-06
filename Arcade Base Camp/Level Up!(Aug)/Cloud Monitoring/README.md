# Cloud Monitoring: Qwik Start

<h2>📋 Steps</h2>

<ol>

  <li>Open <b>Cloud Shell</b>.</li>

  <li>Paste the following script into Cloud Shell and run it:</li>

```bash
#!/bin/bash

DIM=$'\033[2;37m'
RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
GOLD=$'\033[1;33m'
SKY=$'\033[1;36m'
PURPLE=$'\033[1;35m'
WHITE=$'\033[1;97m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

clear

printf "\n${SKY}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${WHITE}${BOLD}            Google Cloud VM Setup${RESET}\n"
printf "${SKY}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"

printf "${GOLD}${BOLD}Enter Zone: ${RESET}"
read -r ZONE
export ZONE

printf "\n${SKY}${BOLD}▶ Creating Compute Engine VM...${RESET}\n"

gcloud compute instances create lamp-1-vm \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --tags=http-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=lamp-1-vm,image=projects/debian-cloud/global/images/debian-12-bookworm-v20240709,mode=rw,size=10,type=projects/$DEVSHELL_PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any

printf "\n${PURPLE}${BOLD}▶ Configuring Firewall Rule...${RESET}\n"

gcloud compute firewall-rules create allow-http \
    --project=$DEVSHELL_PROJECT_ID \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

sleep 10

printf "\n${SKY}${BOLD}▶ Installing Apache & PHP...${RESET}\n"

gcloud compute ssh lamp-1-vm --zone=$ZONE --command "
sudo apt-get update &&
sudo apt-get install apache2 php7.0 -y &&
sudo service apache2 restart
"

sleep 10

printf "\n${GREEN}${BOLD}▶ Retrieving Instance ID...${RESET}\n"

EXTERNAL_IP=$(gcloud compute instances describe lamp-1-vm \
  --zone=$ZONE \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

printf "\n${GOLD}${BOLD}▶ Creating Uptime Check...${RESET}\n"

gcloud monitoring uptime create "Lamp Uptime Check" \
  --resource-type=uptime-url \
  --resource-labels=host=$EXTERNAL_IP \
  --protocol=http \
  --path=/ \
  --period=1

printf "\n${PURPLE}${BOLD}▶ Creating Notification Channel...${RESET}\n"

cat > email-channel.json <<EOF
{
  "type": "email",
  "displayName": "arcadecrew",
  "description": "arcadecrew",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

gcloud beta monitoring channels create \
--channel-content-from-file="email-channel.json"

printf "\n${SKY}${BOLD}▶ Fetching Notification Channel ID...${RESET}\n"

channel_info=$(gcloud beta monitoring channels list)
channel_id=$(echo "$channel_info" | grep -oP 'name: \K[^ ]+' | head -n 1)

printf "\n${RED}${BOLD}▶ Creating Alert Policy...${RESET}\n"

cat > app-engine-error-percent-policy.json <<EOF
{
  "displayName": "Inbound Traffic Alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "VM Instance - Network traffic",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/interface/traffic\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "60s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 500
      }
    }
  ],
  "alertStrategy": {},
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "$channel_id"
  ],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF

gcloud alpha monitoring policies create \
--policy-from-file="app-engine-error-percent-policy.json"

INSTANCE_ID=$(gcloud compute instances describe lamp-1-vm \
--zone=$ZONE \
--format='value(id)')

printf "\n${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${GREEN}${BOLD}        ✔ Lab Completed Successfully ✔${RESET}\n"
printf "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"
```

  <li>When prompted, enter your <b>zone</b> in Cloud Shell.</li>

</ol>
# Monitor an Apache Web Server using Ops Agent

<h2>📋 Steps</h2>

<ol>

  <li>Open <b>Cloud Shell</b>.</li>

  <li>Paste the following script into Cloud Shell and run it:</li>

```bash
#!/bin/bash

DIM=$'\033[2;37m'
LIME=$'\033[1;92m'
AQUA=$'\033[1;96m'
GOLD=$'\033[1;93m'
PINK=$'\033[1;95m'
WHITE=$'\033[1;97m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

clear

printf "\n${AQUA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${LIME}                 Google Cloud Monitoring Setup${RESET}\n"
printf "${AQUA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"

gcloud auth list

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_ID=$DEVSHELL_PROJECT_ID
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

gcloud config set compute/zone $ZONE

printf "\n${GOLD}➜ Creating Compute Engine VM...${RESET}\n"

gcloud compute instances create quickstart-vm \
--project=$DEVSHELL_PROJECT_ID \
--zone=$ZONE \
--machine-type=e2-small \
--image-family=debian-11 \
--image-project=debian-cloud \
--tags=http-server,https-server && \
gcloud compute firewall-rules create default-allow-http \
--target-tags=http-server \
--allow tcp:80 \
--description="Allow HTTP traffic" && \
gcloud compute firewall-rules create default-allow-https \
--target-tags=https-server \
--allow tcp:443 \
--description="Allow HTTPS traffic"

cat > cp_disk.sh <<'EOF_CP'
#!/bin/bash

sudo apt-get update && sudo apt-get install apache2 php7.0 -y

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

set -e

sudo cp /etc/google-cloud-ops-agent/config.yaml /etc/google-cloud-ops-agent/config.yaml.bak

sudo tee /etc/google-cloud-ops-agent/config.yaml > /dev/null << EOF
metrics:
  receivers:
    apache:
      type: apache
  service:
    pipelines:
      apache:
        receivers:
          - apache
logging:
  receivers:
    apache_access:
      type: apache_access
    apache_error:
      type: apache_error
  service:
    pipelines:
      apache:
        receivers:
          - apache_access
          - apache_error
EOF

sudo service google-cloud-ops-agent restart
sleep 60
EOF_CP

printf "\n${GOLD}➜ Copying setup script to VM...${RESET}\n"

gcloud compute scp cp_disk.sh quickstart-vm:/tmp \
--project=$DEVSHELL_PROJECT_ID \
--zone=$ZONE \
--quiet

printf "\n${GOLD}➜ Configuring Apache & Ops Agent...${RESET}\n"

gcloud compute ssh quickstart-vm \
--project=$DEVSHELL_PROJECT_ID \
--zone=$ZONE \
--quiet \
--command="bash /tmp/cp_disk.sh"

cat > cp-channel.json <<EOF_CP
{
  "type": "pubsub",
  "displayName": "Hello",
  "description": "World",
  "labels": {
    "topic": "projects/$DEVSHELL_PROJECT_ID/topics/notificationTopic"
  }
}
EOF_CP

printf "\n${GOLD}➜ Creating Monitoring Notification Channel...${RESET}\n"

gcloud beta monitoring channels create \
--channel-content-from-file=cp-channel.json

email_channel=$(gcloud beta monitoring channels list)
channel_id=$(echo "$email_channel" | grep -oP 'name: \K[^ ]+' | head -n 1)

cat > stopped-vm-alert-policy.json <<EOF_CP
{
  "displayName": "Apache traffic above threshold",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "VM Instance - workload/apache.traffic",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"workload.googleapis.com/apache.traffic\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 4000
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "1800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "$channel_id"
  ],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF_CP

printf "\n${GOLD}➜ Creating Alert Policy...${RESET}\n"

gcloud alpha monitoring policies create \
--policy-from-file=stopped-vm-alert-policy.json

printf "\n${AQUA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${LIME}                    ✔ Setup Completed Successfully${RESET}\n"
printf "${AQUA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"
```

</ol>
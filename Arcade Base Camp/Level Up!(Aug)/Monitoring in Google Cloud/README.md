# Monitoring in Google Cloud: Challenge Lab

<h2>📋 Steps</h2>

<ol>

  <li>Open <b>Cloud Shell</b>.</li>

  <li>Paste the following script into Cloud Shell and run it.</li>

```bash
#!/bin/bash
set -euo pipefail

LIME=$'\033[1;92m'
AQUA=$'\033[1;96m'
GOLD=$'\033[1;93m'
PINK=$'\033[1;95m'
WHITE=$'\033[1;97m'
RESET=$'\033[0m'
BOLD=$'\033[1m'
UNDERLINE=$'\033[4m'

clear

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
INSTANCE_NAME=$(gcloud compute instances list --project="$PROJECT_ID" --format='value(name)' --limit=1)
ZONE_URI=$(gcloud compute instances list --project="$PROJECT_ID" --format='value(zone)' --limit=1)
ZONE=${ZONE_URI##*/}
VM_EXTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "${PINK}${BOLD}╔════════════════════════════════════════════════════╗${RESET}"
echo "${PINK}${BOLD}║            MONITORING IN GOOGLE CLOUD             ║${RESET}"
echo "${PINK}${BOLD}╚════════════════════════════════════════════════════╝${RESET}"
echo
echo "${AQUA}${BOLD}▶ Target VM${RESET}"
echo "${WHITE}├─ ${GOLD}Instance Name ${WHITE}: ${LIME}$INSTANCE_NAME${RESET}"
echo "${WHITE}├─ ${GOLD}Zone          ${WHITE}: ${LIME}$ZONE${RESET}"
echo "${WHITE}└─ ${GOLD}External IP   ${WHITE}: ${LIME}$VM_EXTERNAL_IP${RESET}"
echo

cat > install_ops_agent.sh <<'EOF'
#!/bin/bash
set -e

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

sudo mkdir -p /etc/google-cloud-ops-agent

cat <<'EOC' | sudo tee /etc/google-cloud-ops-agent/config.yaml >/dev/null
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
metrics:
  receivers:
    apache:
      type: apache
  service:
    pipelines:
      apache:
        receivers:
        - apache
EOC

sudo systemctl restart google-cloud-ops-agent
sudo systemctl is-active google-cloud-ops-agent
sudo systemctl status google-cloud-ops-agent* --no-pager || true
EOF

gcloud compute scp install_ops_agent.sh "$INSTANCE_NAME":/tmp --zone="$ZONE" --quiet
gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --quiet --command="bash /tmp/install_ops_agent.sh"

echo "${LIME}${BOLD}✔ Task 1 completed${RESET}"
echo

echo "${AQUA}${BOLD}▶ Task 2: Uptime Check${RESET}"

gcloud monitoring uptime create hello \
  --resource-type=uptime-url \
  --resource-labels=host="$VM_EXTERNAL_IP",path=/,port=80 || true

echo "${LIME}${BOLD}✔ Uptime check created${RESET}"
echo

echo "${AQUA}${BOLD}▶ Creating Notification Channel${RESET}"

cat > email-channel.json <<EOF
{
  "type": "email",
  "displayName": "hello",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

gcloud beta monitoring channels create \
  --channel-content-from-file=email-channel.json

CHANNEL_ID=$(gcloud beta monitoring channels list \
  --format="value(name)" | head -n 1)

echo "${LIME}${BOLD}✔ Notification channel created${RESET}"
echo

echo "${AQUA}${BOLD}▶ Creating Alert Policy${RESET}"

channel_info=$(gcloud beta monitoring channels list)
channel_id=$(echo "$channel_info" | grep -oP 'name: \K[^ ]+' | head -n 1)

cat > app-engine-error-percent-policy.json <<EOF_CP
{
  "displayName": "alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "VM Instance - Traffic",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/apache/traffic\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "300s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 3072
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

gcloud alpha monitoring policies create \
  --policy-from-file="app-engine-error-percent-policy.json"

echo "${LIME}${BOLD}✔ Alert policy created successfully${RESET}"
echo

echo "${AQUA}${BOLD}▶ Creating Log-Based Metric${RESET}"

PROJECT_ID=$(gcloud config get-value project)

gcloud logging metrics create drabhi \
  --description="Count Apache 200 OK responses" \
  --log-filter='resource.type="gce_instance"
logName="projects/'"$PROJECT_ID"'/logs/apache-access"
textPayload:"200"'

echo "${LIME}${BOLD}✔ Log-based metric 'drabhi' created${RESET}"
echo

echo "${PINK}${BOLD}══════════════════════════════════════════════════════${RESET}"
echo "${WHITE}${BOLD}Dashboard : ${GOLD}${UNDERLINE}https://console.cloud.google.com/monitoring/dashboards?&project=$PROJECT_ID${RESET}"
echo "${WHITE}${BOLD}Metrics   : ${GOLD}${UNDERLINE}https://console.cloud.google.com/logs/metrics/edit?project=$PROJECT_ID${RESET}"
echo "${PINK}${BOLD}══════════════════════════════════════════════════════${RESET}"
```

  <li>Open <b>Logs Explorer → Metrics</b> by visiting the following link:</li>

https://console.cloud.google.com/logs/metrics/edit?

  <li>Navigate to <b>Dashboard → Create Custom Dashboard → Add Widget → Line Chart</b>.</li>

  <li>Select the required <b>metric</b> from the lab and click <b>Apply</b>.</li>

  <li>Click <b>Add Widget → Line Chart</b> again, select the second required <b>metric</b>, and click <b>Apply</b>.</li>

  <li>Open the following link again:</li>

https://console.cloud.google.com/logs/metrics/edit?

  <li>Set the metric name to <b>hello</b>.</li>

  <li>Paste the following filter into the <b>Filter</b> field, replacing <b>PROJECT_ID</b> with your own Google Cloud Project ID.</li>

```text
resource.type="gce_instance"
logName="projects/PROJECT_ID/logs/apache-access"
textPayload:"200"
```

  <li>Click <b>Create Metric</b>.</li>

</ol>
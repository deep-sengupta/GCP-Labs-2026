# Debug Apps on Google Kubernetes Engine

<h2>📋 Steps</h2>

<ol>

  <li>Open <b>Cloud Shell</b>.</li>

  <li>Set your <b>zone</b>:</li>

```bash
export ZONE=YOUR_ZONE
```

  <li>Run the following script:</li>

```bash
#!/bin/bash

CRIMSON=$'\033[1;91m'
LIME=$'\033[1;92m'
AMBER=$'\033[1;93m'
SKY=$'\033[1;94m'
VIOLET=$'\033[1;95m'
AQUA=$'\033[1;96m'
PEARL=$'\033[1;97m'
MINT=$'\033[38;5;49m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

clear

printf "\n${AQUA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${MINT}${BOLD}              Google Cloud Deployment Setup${RESET}\n"
printf "${AQUA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"

while true; do
  printf "${SKY}${BOLD}➜ Enter your GCP Zone (e.g. us-central1-a): ${RESET}"
  read -r ZONE

  if [[ -n "$ZONE" ]]; then
    printf "\n${LIME}✓ Zone selected: ${PEARL}%s${RESET}\n\n" "$ZONE"
    break
  else
    printf "${CRIMSON}✗ Zone cannot be empty. Please try again.${RESET}\n\n"
  fi
done

gcloud config set compute/zone "$ZONE"

export PROJECT_ID=$(gcloud info --format='value(config.project)')

gcloud container clusters get-credentials central --zone "$ZONE"

git clone https://github.com/xiangshen-dk/microservices-demo.git
cd microservices-demo

kubectl apply -f release/kubernetes-manifests.yaml

sleep 30

gcloud logging metrics create Error_Rate_SLI \
  --description="Error rate for recommendationservice" \
  --log-filter="resource.type=\"k8s_container\" severity=ERROR labels.\"k8s-pod/app\": \"recommendationservice\""

sleep 30

cat > awesome.json <<EOF
{
  "displayName": "Error Rate SLI",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "Kubernetes Container - logging/user/Error_Rate_SLI",
      "conditionThreshold": {
        "filter": "resource.type = \"k8s_container\" AND metric.type = \"logging.googleapis.com/user/Error_Rate_SLI\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 0.5
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF

gcloud alpha monitoring policies create --policy-from-file="awesome.json"

printf "\n${AQUA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${LIME}${BOLD}✔ Deployment Completed Successfully${RESET}\n"
printf "${AQUA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
```

  <li>When prompted, enter your <b>zone</b> in the Cloud Shell.</li>

</ol>
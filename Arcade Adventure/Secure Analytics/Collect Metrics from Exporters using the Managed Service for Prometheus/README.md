# Collect Metrics from Exporters using the Managed Service for Prometheus

<h2>📋 Steps</h2>

<ol>

  <li>Open <b>Cloud Shell</b>.</li>

  <li>Paste the following script into Cloud Shell and run it:</li>

```bash
#!/bin/bash

EMERALD=$'\033[1;92m'
SKY=$'\033[1;96m'
GOLD=$'\033[1;93m'
PURPLE=$'\033[1;95m'
WHITE=$'\033[1;97m'
GRAY=$'\033[1;90m'

BG_BLACK=$(tput setab 0)
BG_BLUE=$(tput setab 4)
BG_CYAN=$(tput setab 6)
BG_WHITE=$(tput setab 7)

BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "${SKY}${BOLD}════════════════════════════════════════════════════════════${RESET}"
echo "${WHITE}${BOLD}                GOOGLE MANAGED PROMETHEUS SETUP            ${RESET}"
echo "${SKY}${BOLD}════════════════════════════════════════════════════════════${RESET}"
echo

echo "${PURPLE}${BOLD}▶ Environment Configuration${RESET}"
read -p "${GOLD}Enter Zone (Example: us-central1-a): ${RESET}" ZONE
export ZONE
echo
echo "${EMERALD}✔ Active Zone:${RESET} ${WHITE}${BOLD}$ZONE${RESET}"
echo

echo "${PURPLE}${BOLD}▶ Creating GKE Cluster${RESET}"
gcloud beta container clusters create gmp-cluster \
  --num-nodes=1 \
  --zone=$ZONE \
  --enable-managed-prometheus
echo
echo "${EMERALD}✔ Cluster created successfully.${RESET}"
echo

echo "${PURPLE}${BOLD}▶ Configuring Cluster Access${RESET}"
gcloud container clusters get-credentials gmp-cluster --zone=$ZONE
echo
echo "${EMERALD}✔ Credentials configured.${RESET}"
echo

echo "${PURPLE}${BOLD}▶ Deploying Monitoring Application${RESET}"
kubectl create ns gmp-test
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/example-app.yaml
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/pod-monitoring.yaml
echo
echo "${EMERALD}✔ Application deployed successfully.${RESET}"
echo

echo "${PURPLE}${BOLD}▶ Installing Prometheus${RESET}"
git clone https://github.com/GoogleCloudPlatform/prometheus
cd prometheus
git checkout v2.28.1-gmp.4
wget https://storage.googleapis.com/kochasoft/gsp1026/prometheus

export PROJECT_ID=$(gcloud config get-value project)

echo
echo "${WHITE}${BOLD}Project ID:${RESET} ${EMERALD}$PROJECT_ID${RESET}"
echo

./prometheus \
  --config.file=documentation/examples/prometheus.yml \
  --export.label.project-id=$PROJECT_ID \
  --export.label.location=$ZONE

echo
echo "${EMERALD}✔ Prometheus started successfully.${RESET}"
echo

echo "${PURPLE}${BOLD}▶ Installing Node Exporter${RESET}"
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.3.1.linux-amd64.tar.gz
cd node_exporter-1.3.1.linux-amd64

cat > config.yaml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets: ['localhost:9100']
EOF

export PROJECT=$(gcloud config get-value project)

gsutil mb -p $PROJECT gs://$PROJECT
gsutil cp config.yaml gs://$PROJECT
gsutil -m acl set -R -a public-read gs://$PROJECT

echo
echo "${SKY}${BOLD}════════════════════════════════════════════════════════════${RESET}"
echo "${EMERALD}${BOLD}           ✔ GOOGLE MANAGED PROMETHEUS SETUP COMPLETE      ${RESET}"
echo "${SKY}${BOLD}════════════════════════════════════════════════════════════${RESET}"
```

  <li>When prompted, enter your <b>zone</b> in the Cloud Shell.</li>

</ol>
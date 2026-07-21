#!/bin/bash

BOLD=$'\033[1m'
UNDERLINE=$'\033[4m'
RESET=$'\033[0m'

RED=$'\033[38;5;203m'
GREEN=$'\033[38;5;84m'
YELLOW=$'\033[38;5;227m'
BLUE=$'\033[38;5;75m'
PURPLE=$'\033[38;5;141m'
CYAN=$'\033[38;5;51m'
WHITE=$'\033[38;5;255m'
ORANGE=$'\033[38;5;214m'

clear

echo "${PURPLE}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "              GKE AUTOSCALING LAB AUTOMATION                "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${RESET}"

read -p "${WHITE}${BOLD}ZONE:${RESET} ${CYAN}" ZONE
read -p "${WHITE}${BOLD}CLUSTER NAME:${RESET} ${CYAN}" CLUSTER_NAME
read -p "${WHITE}${BOLD}NODE POOL:${RESET} ${CYAN}" POOL_NAME
read -p "${WHITE}${BOLD}MAX REPLICAS:${RESET} ${CYAN}" MAX_REPLICAS

echo "${RESET}"
echo "${GREEN}${BOLD}✓ Configuration Loaded${RESET}"
echo

echo "${BLUE}${BOLD}▶ Checking Authentication${RESET}"
gcloud auth list
echo

PROJECT=$(gcloud config get-value project)
echo "${WHITE}${BOLD}Project:${RESET} ${YELLOW}$PROJECT${RESET}"
echo

echo "${CYAN}${BOLD}▶ Creating GKE Cluster${RESET}"
gcloud container clusters create $CLUSTER_NAME \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --num-nodes=2 || {
    echo "${RED}${BOLD}✖ Cluster creation failed${RESET}"
    exit 1
}
echo "${GREEN}${BOLD}✓ Cluster Ready${RESET}"
echo

echo "${CYAN}${BOLD}▶ Creating Namespaces${RESET}"
kubectl create namespace dev
kubectl create namespace prod
echo "${GREEN}${BOLD}✓ Namespaces Created${RESET}"
echo

echo "${ORANGE}${BOLD}▶ Deploying Microservices${RESET}"
git clone -q https://github.com/GoogleCloudPlatform/microservices-demo.git &&
cd microservices-demo &&
kubectl apply -f ./release/kubernetes-manifests.yaml --namespace dev || {
    echo "${RED}${BOLD}✖ Deployment failed${RESET}"
    exit 1
}
echo "${GREEN}${BOLD}✓ Deployment Complete${RESET}"
echo

echo "${PURPLE}${BOLD}▶ Creating Custom Node Pool${RESET}"
gcloud container node-pools create $POOL_NAME \
    --cluster=$CLUSTER_NAME \
    --machine-type=custom-2-3584 \
    --num-nodes=2 \
    --zone=$ZONE || {
    echo "${RED}${BOLD}✖ Node pool creation failed${RESET}"
    exit 1
}
echo "${GREEN}${BOLD}✓ Node Pool Ready${RESET}"
echo

echo "${BLUE}${BOLD}▶ Migrating Workloads${RESET}"
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name); do
    kubectl cordon "$node"
done

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name); do
    kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 "$node"
done

kubectl get pods -o=wide --namespace=dev
echo "${GREEN}${BOLD}✓ Migration Finished${RESET}"
echo

echo "${RED}${BOLD}▶ Removing Default Node Pool${RESET}"
gcloud container node-pools delete default-pool \
    --cluster=$CLUSTER_NAME \
    --project=$DEVSHELL_PROJECT_ID \
    --zone $ZONE \
    --quiet || {
    echo "${YELLOW}${BOLD}⚠ Default pool already removed${RESET}"
}
echo "${GREEN}${BOLD}✓ Default Pool Removed${RESET}"
echo

echo "${CYAN}${BOLD}▶ Creating Pod Disruption Budget${RESET}"
kubectl create poddisruptionbudget onlineboutique-frontend-pdb \
    --selector app=frontend \
    --min-available 1 \
    --namespace dev || {
    echo "${RED}${BOLD}✖ Failed to create PDB${RESET}"
    exit 1
}
echo "${GREEN}${BOLD}✓ PDB Created${RESET}"
echo

echo "${ORANGE}${BOLD}▶ Updating Frontend Deployment${RESET}"
kubectl patch deployment frontend -n dev --type=json -p '[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/image",
    "value": "gcr.io/qwiklabs-resources/onlineboutique-frontend:v2.1"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/imagePullPolicy",
    "value": "Always"
  }
]' || {
    echo "${RED}${BOLD}✖ Deployment update failed${RESET}"
    exit 1
}
echo "${GREEN}${BOLD}✓ Frontend Updated${RESET}"
echo

echo "${PURPLE}${BOLD}▶ Configuring Horizontal Pod Autoscaler${RESET}"
kubectl autoscale deployment frontend \
    --cpu-percent=50 \
    --min=1 \
    --max=$MAX_REPLICAS \
    --namespace dev || {
    echo "${RED}${BOLD}✖ HPA configuration failed${RESET}"
    exit 1
}

kubectl get hpa --namespace dev
echo "${GREEN}${BOLD}✓ HPA Enabled${RESET}"
echo

echo "${BLUE}${BOLD}▶ Enabling Cluster Autoscaling${RESET}"
gcloud beta container clusters update $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$DEVSHELL_PROJECT_ID \
    --enable-autoscaling \
    --min-nodes 1 \
    --max-nodes 6 || {
    echo "${RED}${BOLD}✖ Cluster autoscaling failed${RESET}"
    exit 1
}
echo "${GREEN}${BOLD}✓ Cluster Autoscaling Enabled${RESET}"
echo

echo "${GREEN}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                  LAB COMPLETED SUCCESSFULLY                "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${RESET}"
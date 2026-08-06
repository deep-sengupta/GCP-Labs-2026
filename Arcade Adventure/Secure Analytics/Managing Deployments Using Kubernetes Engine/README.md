# Managing Deployments Using Kubernetes Engine

<h2>📋 Steps</h2>

<ol>

  <li>Open <b>Cloud Shell</b>.</li>

  <li>Paste the following script into Cloud Shell and run it:</li>

```bash
#!/bin/bash

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
NC='\e[0m'

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

print_header() {
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} ${CYAN}$1${NC} ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header "Fetching Google Cloud Configuration"
print_info "Getting zone, region, and project details..."

ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$ZONE" ] || [ -z "$REGION" ] || [ -z "$PROJECT_ID" ]; then
    print_error "Failed to get Google Cloud configuration. Please check your gcloud setup."
    exit 1
fi

print_success "Zone: $ZONE"
print_success "Region: $REGION"
print_success "Project ID: $PROJECT_ID"

print_info "Setting compute zone..."
gcloud config set compute/zone "$ZONE"

print_header "Setting up Kubernetes Resources"
print_info "Copying Kubernetes configuration files..."
gcloud storage cp -r gs://spls/gsp053/kubernetes . &
spinner $!
wait

cd kubernetes || exit 1

print_header "Creating GKE Cluster"
print_info "Creating Kubernetes cluster with 3 nodes..."
gcloud container clusters create bootcamp --machine-type e2-small --num-nodes 3 --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw" &
spinner $!
wait
print_success "GKE cluster created successfully!"

print_header "TASK 1: Creating Fortune App Deployment and Service"

if [ -f deployments/fortune-app.yaml ]; then
    print_info "Creating fortune-app deployment..."
    kubectl apply -f deployments/fortune-app.yaml &
    spinner $!
    wait
elif [ -f deployments/fortune-app-blue.yaml ]; then
    print_info "Creating fortune-app blue deployment..."
    kubectl apply -f deployments/fortune-app-blue.yaml &
    spinner $!
    wait
else
    print_error "Deployment file not found."
    exit 1
fi

if [ -f services/fortune-app.yaml ]; then
    print_info "Creating fortune-app service..."
    kubectl apply -f services/fortune-app.yaml &
    spinner $!
    wait
else
    print_error "Service file not found."
    exit 1
fi

kubectl rollout status deployment/fortune-app 2>/dev/null || kubectl rollout status deployment/fortune-app-blue 2>/dev/null

print_header "TASK 2: Deploying Fortune App (Blue)"
print_info "Creating deployment and service..."
kubectl create -f deployments/fortune-app-blue.yaml 2>/dev/null || kubectl apply -f deployments/fortune-app-blue.yaml &
spinner $!
wait
kubectl create -f services/fortune-app.yaml 2>/dev/null || kubectl apply -f services/fortune-app.yaml &
spinner $!
wait

print_info "Scaling deployment to 5 replicas..."
kubectl scale deployment fortune-app-blue --replicas=5 &
spinner $!
wait
COUNT=$(kubectl get pods | grep fortune-app-blue | wc -l | tr -d ' ')
print_success "Current replicas: $COUNT"

print_info "Scaling deployment to 3 replicas..."
kubectl scale deployment fortune-app-blue --replicas=3 &
spinner $!
wait
COUNT=$(kubectl get pods | grep fortune-app-blue | wc -l | tr -d ' ')
print_success "Current replicas: $COUNT"

print_header "TASK 3: Canary Deployment"
echo -e "${YELLOW}🎯 This task will perform a canary deployment strategy${NC}"
echo -ne "${CYAN}? Do you want to continue with Task 3? ${NC}[${GREEN}Y${NC}/${RED}N${NC}]: "
read -r CONFIRM

if [[ "$CONFIRM" != "Y" && "$CONFIRM" != "y" ]]; then
    print_warning "Task 3 aborted by user."
    exit 0
fi

print_info "Updating container image to version 2.0.0..."
kubectl set image deployment/fortune-app-blue fortune-app="$REGION-docker.pkg.dev/qwiklabs-resources/spl-lab-apps/fortune-service:2.0.0" &
spinner $!
wait

print_info "Setting environment variable..."
kubectl set env deployment/fortune-app-blue APP_VERSION=2.0.0 &
spinner $!
wait

print_info "Creating canary deployment..."
kubectl create -f deployments/fortune-app-canary.yaml 2>/dev/null || kubectl apply -f deployments/fortune-app-canary.yaml &
spinner $!
wait
print_success "Canary deployment created successfully!"

print_header "TASK 5: Blue-Green Deployment"
print_info "Setting up blue service..."
kubectl apply -f services/fortune-app-blue-service.yaml &
spinner $!
wait

print_info "Creating green deployment..."
kubectl create -f deployments/fortune-app-green.yaml 2>/dev/null || kubectl apply -f deployments/fortune-app-green.yaml &
spinner $!
wait

print_info "Setting up green service..."
kubectl apply -f services/fortune-app-green-service.yaml &
spinner $!
wait

print_info "Updating blue service..."
kubectl apply -f services/fortune-app-blue-service.yaml &
spinner $!
wait

print_success "Blue-Green deployment setup completed!"

print_header "Lab Completion Status"
echo -e "${GREEN}🎉 All tasks completed successfully!${NC}"
echo -e "${CYAN}📊 Current deployments:${NC}"
kubectl get deployments
echo -e "\n${CYAN}🌐 Current services:${NC}"
kubectl get services
echo -e "\n${CYAN}🐳 Current pods:${NC}"
kubectl get pods
```

  <li>Wait for the script to finish and complete the lab.</li>

</ol>
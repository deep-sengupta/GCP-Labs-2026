# Manage Kubernetes in Google Cloud: Challenge Lab

<h2>📋 Steps</h2>

<ol>

  <li>Open <b>Cloud Shell</b>.</li>

  <li>Paste the following script into Cloud Shell and run it:</li>

```bash
#!/bin/bash
set -euo pipefail

C0=$'\033[0m'
C1=$'\033[1;36m'
C2=$'\033[1;32m'
C3=$'\033[1;33m'
C4=$'\033[1;35m'
C5=$'\033[1;34m'
C6=$'\033[1;31m'
C7=$'\033[1;37m'
B1=$(tput bold)
R1=$(tput sgr0)

banner() {
  printf "\n%s%s%s\n" "${C4}${B1}" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "${R1}"
  printf "%s%s%s\n" "${C1}${B1}" "$1" "${R1}"
  printf "%s%s%s\n\n" "${C4}${B1}" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "${R1}"
}

ok() {
  printf "%s%s%s\n" "${C2}${B1}" "$1" "${R1}"
}

info() {
  printf "%s%s%s\n" "${C3}${B1}" "$1" "${R1}"
}

label() {
  printf "%s%s%s" "${C7}${B1}" "$1" "${R1}"
}

banner "CONFIGURATION PARAMETERS"

read -p "$(label 'Enter CLUSTER_NAME (e.g., monitoring-cluster): ')" CLUSTER_NAME
read -p "$(label 'Enter ZONE (e.g., us-central1-a): ')" ZONE
read -p "$(label 'Enter NAMESPACE (e.g., gmp-test): ')" NAMESPACE
read -p "$(label 'Enter REPO_NAME (e.g., hello-repo): ')" REPO_NAME
read -p "$(label 'Enter INTERVAL for monitoring (e.g., 30s): ')" INTERVAL
read -p "$(label 'Enter SERVICE_NAME (e.g., hello-service): ')" SERVICE_NAME

export CLUSTER_NAME ZONE NAMESPACE REPO_NAME INTERVAL SERVICE_NAME
export REGION="${ZONE%-*}"
export PROJECT_ID="$(gcloud config get-value project)"

printf "\n%s\n" "${C5}${B1}Configuration Summary:${R1}"
printf "%s%s%s\n" "${C7}${B1}" "Cluster Name: " "${R1}${CLUSTER_NAME}"
printf "%s%s%s\n" "${C7}${B1}" "Zone: " "${R1}${ZONE}"
printf "%s%s%s\n" "${C7}${B1}" "Region: " "${R1}${REGION}"
printf "%s%s%s\n" "${C7}${B1}" "Namespace: " "${R1}${NAMESPACE}"
printf "%s%s%s\n" "${C7}${B1}" "Repository: " "${R1}${REPO_NAME}"
printf "%s%s%s\n" "${C7}${B1}" "Monitoring Interval: " "${R1}${INTERVAL}"
printf "%s%s%s\n\n" "${C7}${B1}" "Service Name: " "${R1}${SERVICE_NAME}"

banner "CLUSTER CREATION"

info "Setting compute zone..."
gcloud config set compute/zone "$ZONE"

info "Creating GKE cluster with autoscaling..."
gcloud container clusters create "$CLUSTER_NAME" \
  --release-channel regular \
  --cluster-version latest \
  --num-nodes 3 \
  --min-nodes 2 \
  --max-nodes 6 \
  --enable-autoscaling \
  --no-enable-ip-alias

info "Enabling Managed Prometheus..."
gcloud container clusters update "$CLUSTER_NAME" \
  --enable-managed-prometheus \
  --zone "$ZONE"

ok "Cluster created and configured successfully!"
printf "\n"

banner "NAMESPACE SETUP"

info "Creating namespace..."
kubectl create ns "$NAMESPACE"
ok "Namespace $NAMESPACE created!"
printf "\n"

banner "PROMETHEUS SETUP"

info "Deploying Prometheus test application..."
cat > prometheus-app.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-test
  labels:
    app: prometheus-test
spec:
  selector:
    matchLabels:
      app: prometheus-test
  replicas: 3
  template:
    metadata:
      labels:
        app: prometheus-test
    spec:
      nodeSelector:
        kubernetes.io/os: linux
        kubernetes.io/arch: amd64
      containers:
      - image: nilebox/prometheus-example-app:latest
        name: prometheus-test
        ports:
        - name: metrics
          containerPort: 1234
        command:
        - "/main"
        - "--process-metrics"
        - "--go-metrics"
EOF

kubectl -n "$NAMESPACE" apply -f prometheus-app.yaml
ok "Prometheus test application deployed!"

info "Configuring Pod Monitoring..."
cat > pod-monitoring.yaml <<EOF
apiVersion: monitoring.googleapis.com/v1alpha1
kind: PodMonitoring
metadata:
  name: prometheus-test
  labels:
    app.kubernetes.io/name: prometheus-test
spec:
  selector:
    matchLabels:
      app: prometheus-test
  endpoints:
  - port: metrics
    interval: $INTERVAL
EOF

kubectl -n "$NAMESPACE" apply -f pod-monitoring.yaml
ok "Pod monitoring configured with ${INTERVAL} interval!"
printf "\n"

banner "HELLO APPLICATION DEPLOYMENT"

info "Setting up hello application..."
gsutil cp -r gs://spls/gsp510/hello-app/ .
cd ~/hello-app

info "Deploying initial version..."
kubectl -n "$NAMESPACE" apply -f manifests/helloweb-deployment.yaml
ok "Initial deployment complete!"

info "Updating deployment configuration..."
cat > manifests/helloweb-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 200m
EOF

kubectl delete deployments helloweb -n "$NAMESPACE"
kubectl -n "$NAMESPACE" apply -f manifests/helloweb-deployment.yaml
ok "Deployment updated!"
printf "\n"

banner "APPLICATION UPDATE"

info "Building and pushing new version..."
cat > main.go <<EOF
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", hello)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func hello(w http.ResponseWriter, r *http.Request) {
	log.Printf("Serving request: %s", r.URL.Path)
	host, _ := os.Hostname()
	fmt.Fprintf(w, "Hello, world!\\n")
	fmt.Fprintf(w, "Version: 2.1.0\\n")
	fmt.Fprintf(w, "Hostname: %s\\n", host)
}
EOF

gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet
docker build -t "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2" .
docker push "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2"

info "Updating deployment with new image..."
kubectl set image deployment/helloweb -n "$NAMESPACE" hello-app="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2"

info "Exposing service..."
kubectl expose deployment helloweb -n "$NAMESPACE" --name="$SERVICE_NAME" --type=LoadBalancer --port 8080 --target-port 8080
ok "Application updated and service exposed!"
printf "\n"

banner "MONITORING CONFIGURATION"

info "Creating logging metric..."
gcloud logging metrics create pod-image-errors \
  --description="Pod image errors monitoring" \
  --log-filter='resource.type="k8s_pod" severity=WARNING'

info "Creating alert policy..."
cat > awesome.json <<EOF
{
  "displayName": "Pod Error Alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "Kubernetes Pod - logging/user/pod-image-errors",
      "conditionThreshold": {
        "filter": "resource.type = \"k8s_pod\" AND metric.type = \"logging.googleapis.com/user/pod-image-errors\"",
        "aggregations": [
          {
            "alignmentPeriod": "600s",
            "crossSeriesReducer": "REDUCE_SUM",
            "perSeriesAligner": "ALIGN_COUNT"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 0
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": []
}
EOF

gcloud alpha monitoring policies create --policy-from-file="awesome.json"
ok "Monitoring and alerting configured!"
printf "\n"
```

  <li>When prompted, enter your <b>cluster name</b>, <b>zone</b>, <b>namespace</b>, <b>repo name</b>, <b>interval</b> & <b>service name</b> in the Cloud Shell.</li>

</ol>
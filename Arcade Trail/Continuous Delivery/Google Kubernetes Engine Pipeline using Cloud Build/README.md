# Continuous Delivery with Google Cloud Deploy

<h2>📁 Steps</h2>

<ol>
<li>Open <b>Cloud Shell</b> from the Google Cloud Console.</li>
<li>Run the following command:</li>

```bash
#!/bin/bash
set -euo pipefail

C1=$'\033[38;5;39m'
C2=$'\033[38;5;45m'
C3=$'\033[38;5;82m'
C4=$'\033[38;5;220m'
C5=$'\033[38;5;196m'
C6=$'\033[38;5;141m'
C7=$'\033[38;5;250m'
RST=$'\033[0m'
BOLD=$'\033[1m'

banner() {
  echo
  echo "${C1}${BOLD}╔════════════════════════════════════════════╗${RST}"
  echo "${C1}${BOLD}║      CONTINUOUS DELIVERY LAB RUNNER       ║${RST}"
  echo "${C1}${BOLD}╚════════════════════════════════════════════╝${RST}"
  echo
}

msg() {
  echo "${C2}${BOLD}➤ $1${RST}"
}

ok() {
  echo "${C3}${BOLD}✔ $1${RST}"
}

warn() {
  echo "${C4}${BOLD}⚠ $1${RST}"
}

err() {
  echo "${C5}${BOLD}✖ $1${RST}"
}

sleep_countdown() {
  local seconds="$1"
  local label="$2"
  while [ "$seconds" -gt 0 ]; do
    echo -ne "${C4}${BOLD}\r${label}${seconds}s remaining...${RST}"
    sleep 1
    seconds=$((seconds - 1))
  done
  echo -e "\r${RST}"
}

wait_for_cluster_running() {
  local cluster="$1"
  while true; do
    local state
    state=$(gcloud container clusters describe "$cluster" --region "$REGION" --format="value(status)" 2>/dev/null || true)
    if [ "$state" = "RUNNING" ]; then
      ok "Cluster $cluster is RUNNING"
      break
    fi
    warn "Cluster $cluster is $state"
    sleep_countdown 10 "Waiting for $cluster: "
  done
}

wait_for_rollout_state() {
  local target="$1"
  local desired="$2"
  local state
  while true; do
    state=$(gcloud beta deploy rollouts list \
      --delivery-pipeline web-app \
      --release web-app-001 \
      --filter="targetId=$target" \
      --format="value(state)" | head -n 1 || true)
    if [ "$state" = "$desired" ]; then
      ok "$target rollout reached $desired"
      break
    fi
    if [ "$state" = "FAILED" ] || [ "$state" = "CANCELLED" ] || [ "$state" = "HALTED" ]; then
      err "$target rollout entered $state"
      exit 1
    fi
    sleep_countdown 10 "$target rollout: ${state:-UNKNOWN}. "
  done
}

banner

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION="us-west1"
ZONE="us-west1-c"

export PROJECT_ID
export REGION
export ZONE

msg "Setting region"
gcloud config set compute/region "$REGION" >/dev/null
gcloud config set deploy/region "$REGION" >/dev/null
ok "Region set to $REGION"

msg "Enabling required APIs"
gcloud services enable \
  container.googleapis.com \
  clouddeploy.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com >/dev/null
ok "APIs enabled"

msg "Creating GKE clusters"
for cluster in test staging prod; do
  if gcloud container clusters describe "$cluster" --region "$REGION" >/dev/null 2>&1; then
    ok "Cluster $cluster already exists"
  else
    gcloud container clusters create "$cluster" --node-locations="$ZONE" --num-nodes=1 --async >/dev/null
    ok "Cluster $cluster creation started"
  fi
done

for cluster in test staging prod; do
  wait_for_cluster_running "$cluster"
done

msg "Creating Artifact Registry repository"
if gcloud artifacts repositories describe web-app --location="$REGION" >/dev/null 2>&1; then
  ok "Repository web-app already exists"
else
  gcloud artifacts repositories create web-app \
    --description="Image registry for tutorial web app" \
    --repository-format=docker \
    --location="$REGION" >/dev/null
  ok "Repository web-app created"
fi

msg "Preparing source code"
rm -rf ~/cloud-deploy-tutorials
cd ~/
git clone https://github.com/GoogleCloudPlatform/cloud-deploy-tutorials.git >/dev/null
cd cloud-deploy-tutorials
git checkout c3cae80 --quiet
cd tutorials/base
ok "Source prepared"

msg "Generating Skaffold config"
envsubst < clouddeploy-config/skaffold.yaml.template > web/skaffold.yaml
sed -i "s/{{project-id}}/$PROJECT_ID/g" web/skaffold.yaml
ok "Skaffold config generated"

msg "Ensuring Cloud Build bucket"
if gsutil ls "gs://${PROJECT_ID}_cloudbuild" >/dev/null 2>&1; then
  ok "Cloud Build bucket exists"
else
  gsutil mb -p "$PROJECT_ID" "gs://${PROJECT_ID}_cloudbuild" >/dev/null
  ok "Cloud Build bucket created"
fi

msg "Building images with Skaffold"
cd web
skaffold build --interactive=false \
  --default-repo "$REGION-docker.pkg.dev/$PROJECT_ID/web-app" \
  --file-output artifacts.json
cd ..
ok "Build complete"

msg "Listing deployed images"
gcloud artifacts docker images list \
  "$REGION-docker.pkg.dev/$PROJECT_ID/web-app" \
  --include-tags \
  --format yaml

msg "Showing artifacts metadata"
cat web/artifacts.json | jq
ok "Artifacts metadata ready"

msg "Creating delivery pipeline"
cp clouddeploy-config/delivery-pipeline.yaml.template clouddeploy-config/delivery-pipeline.yaml
gcloud beta deploy apply --file=clouddeploy-config/delivery-pipeline.yaml >/dev/null
ok "Delivery pipeline applied"

msg "Describing delivery pipeline"
gcloud beta deploy delivery-pipelines describe web-app

msg "Getting credentials and setting kubectl contexts"
CONTEXTS=("test" "staging" "prod")
for context in "${CONTEXTS[@]}"; do
  gcloud container clusters get-credentials "$context" --region "$REGION" >/dev/null
  kubectl config rename-context "gke_${PROJECT_ID}_${REGION}_${context}" "$context" >/dev/null 2>&1 || true
done
ok "Contexts configured"

msg "Creating namespace in each cluster"
for context in "${CONTEXTS[@]}"; do
  kubectl --context "$context" apply -f kubernetes-config/web-app-namespace.yaml >/dev/null
done
ok "Namespace created in all clusters"

msg "Creating delivery targets"
for context in "${CONTEXTS[@]}"; do
  envsubst < "clouddeploy-config/target-$context.yaml.template" > "clouddeploy-config/target-$context.yaml"
  gcloud beta deploy apply --file="clouddeploy-config/target-$context.yaml" --region="$REGION" --project="$PROJECT_ID" >/dev/null
done
ok "Targets created"

msg "Creating release web-app-001"
gcloud beta deploy releases create web-app-001 \
  --delivery-pipeline web-app \
  --build-artifacts web/artifacts.json \
  --source web/ \
  --project="$PROJECT_ID" \
  --region="$REGION"
ok "Release created"

msg "Waiting for test rollout"
wait_for_rollout_state test SUCCEEDED
kubectl config use-context test >/dev/null
kubectl get all -n web-app

msg "Promoting to staging"
gcloud beta deploy releases promote \
  --delivery-pipeline web-app \
  --release web-app-001 \
  --quiet
wait_for_rollout_state staging SUCCEEDED
kubectl config use-context staging >/dev/null
kubectl get all -n web-app

msg "Promoting to prod"
gcloud beta deploy releases promote \
  --delivery-pipeline web-app \
  --release web-app-001 \
  --quiet

while true; do
  prod_state=$(gcloud beta deploy rollouts list \
    --delivery-pipeline web-app \
    --release web-app-001 \
    --filter="targetId=prod" \
    --format="value(state)" | head -n 1 || true)
  if [ "$prod_state" = "PENDING_APPROVAL" ]; then
    ok "Prod rollout is pending approval"
    break
  fi
  if [ "$prod_state" = "FAILED" ] || [ "$prod_state" = "CANCELLED" ] || [ "$prod_state" = "HALTED" ]; then
    err "Prod rollout entered $prod_state"
    exit 1
  fi
  sleep_countdown 10 "Waiting for prod approval: ${prod_state:-UNKNOWN}. "
done

prod_rollout_name=$(gcloud beta deploy rollouts list \
  --delivery-pipeline web-app \
  --release web-app-001 \
  --filter="targetId=prod AND state=PENDING_APPROVAL" \
  --format="value(name)" | head -n 1)

if [ -n "$prod_rollout_name" ]; then
  msg "Approving prod rollout"
  gcloud beta deploy rollouts approve "$prod_rollout_name" \
    --delivery-pipeline web-app \
    --release web-app-001 \
    --quiet
  ok "Prod rollout approved"
else
  err "Prod rollout name not found"
  exit 1
fi

wait_for_rollout_state prod SUCCEEDED
kubectl config use-context prod >/dev/null
kubectl get all -n web-app

ok "Lab completed successfully"
```

</ol>
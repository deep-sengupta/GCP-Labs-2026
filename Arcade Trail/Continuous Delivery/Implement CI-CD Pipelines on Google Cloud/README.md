# Implement CI/CD Pipelines on Google Cloud: Challenge Lab

<h2>📁 Steps</h2>

<ol>
<li>Open <b>Cloud Shell</b> from the Google Cloud Console.</li>
<li>Run the following command:</li>

```bash
#!/bin/bash

BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

spinner() {
  local pid=$!
  local delay=0.1
  local spinstr="|/-\\"
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep "$delay"
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

echo
echo "${CYAN_TEXT}${BOLD_TEXT}╔════════════════════════════════════════════════════════╗${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}               CONTINUOUS DELIVERY SETUP                 ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}╚════════════════════════════════════════════════════════╝${RESET_FORMAT}"
echo

echo "${BLUE_TEXT}${BOLD_TEXT}Detecting Google Cloud zone...${RESET_FORMAT}"
ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
if [ -z "$ZONE" ]; then
  echo "${YELLOW_TEXT}${BOLD_TEXT}Default zone not detected.${RESET_FORMAT}"
  while true; do
    read -p "${GREEN_TEXT}${BOLD_TEXT}Enter the zone (example: us-central1-a): ${RESET_FORMAT}" ZONE_INPUT
    if [ -z "$ZONE_INPUT" ]; then
      echo "${RED_TEXT}${BOLD_TEXT}Zone cannot be empty.${RESET_FORMAT}"
    elif [[ "$ZONE_INPUT" =~ ^[a-z0-9]+-[a-z0-9]+-[a-z]$ ]]; then
      ZONE="$ZONE_INPUT"
      break
    else
      echo "${RED_TEXT}${BOLD_TEXT}Invalid zone format.${RESET_FORMAT}"
    fi
  done
fi
echo "${CYAN_TEXT}${BOLD_TEXT}Using Zone: ${WHITE_TEXT}${BOLD_TEXT}$ZONE${RESET_FORMAT}"

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Detecting Google Cloud region...${RESET_FORMAT}"
REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
if [ -z "$REGION" ]; then
  if [ -n "$ZONE" ]; then
    REGION="${ZONE%-*}"
  else
    while true; do
      read -p "${GREEN_TEXT}${BOLD_TEXT}Enter the region (example: us-central1): ${RESET_FORMAT}" REGION_INPUT
      if [ -z "$REGION_INPUT" ]; then
        echo "${RED_TEXT}${BOLD_TEXT}Region cannot be empty.${RESET_FORMAT}"
      elif [[ "$REGION_INPUT" =~ ^[a-z0-9]+-[a-z0-9]+$ ]]; then
        REGION="$REGION_INPUT"
        break
      else
        echo "${RED_TEXT}${BOLD_TEXT}Invalid region format.${RESET_FORMAT}"
      fi
    done
  fi
fi
echo "${CYAN_TEXT}${BOLD_TEXT}Using Region: ${WHITE_TEXT}${BOLD_TEXT}$REGION${RESET_FORMAT}"

echo
PROJECT_ID=$(gcloud config get-value project)
export PROJECT_ID
echo "${CYAN_TEXT}${BOLD_TEXT}Using Project ID: ${WHITE_TEXT}${BOLD_TEXT}$PROJECT_ID${RESET_FORMAT}"

echo
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
export PROJECT_NUMBER
echo "${CYAN_TEXT}${BOLD_TEXT}Using Project Number: ${WHITE_TEXT}${BOLD_TEXT}$PROJECT_NUMBER${RESET_FORMAT}"

export REGION
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
DEFAULT_REPO="$REGION-docker.pkg.dev/$PROJECT_ID/cicd-challenge"

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Setting default compute region...${RESET_FORMAT}"
(gcloud config set compute/region "$REGION") & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Enabling required Google Cloud services...${RESET_FORMAT}"
(gcloud services enable \
  container.googleapis.com \
  clouddeploy.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com) & spinner

echo
echo "${GREEN_TEXT}${BOLD_TEXT}Waiting for services to initialize...${RESET_FORMAT}"
for i in $(seq 20 -1 1); do
  echo -ne "${GREEN_TEXT}${BOLD_TEXT}   $i seconds remaining... \r${RESET_FORMAT}"
  sleep 1
done
echo -e "\n${GREEN_TEXT}${BOLD_TEXT}Services are ready.${RESET_FORMAT}"

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Granting IAM roles...${RESET_FORMAT}"
(gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/clouddeploy.jobRunner") & spinner
echo
(gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/container.developer") & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Creating Artifact Registry repository...${RESET_FORMAT}"
(gcloud artifacts repositories create cicd-challenge \
  --description="Image registry for tutorial web app" \
  --repository-format=docker \
  --location="$REGION") & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Creating GKE clusters...${RESET_FORMAT}"
(gcloud container clusters create cd-staging --node-locations="$ZONE" --num-nodes=1 --async) & spinner
echo "${BLUE_TEXT}${BOLD_TEXT}Creating cd-production...${RESET_FORMAT}"
(gcloud container clusters create cd-production --node-locations="$ZONE" --num-nodes=1 --async) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Preparing source repository...${RESET_FORMAT}"
rm -rf ~/cloud-deploy-tutorials
cd ~/
(git clone https://github.com/GoogleCloudPlatform/cloud-deploy-tutorials.git) & spinner
cd cloud-deploy-tutorials
(git checkout c3cae80 --quiet) & spinner
cd tutorials/base

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Generating Skaffold configuration...${RESET_FORMAT}"
(envsubst < clouddeploy-config/skaffold.yaml.template > web/skaffold.yaml) & spinner
(sed -i "s/{{project-id}}/$PROJECT_ID/g" web/skaffold.yaml) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Checking Cloud Build bucket...${RESET_FORMAT}"
if ! gsutil ls "gs://${PROJECT_ID}_cloudbuild/" &>/dev/null; then
  (gsutil mb -p "$PROJECT_ID" -l "$REGION" -b on "gs://${PROJECT_ID}_cloudbuild/") & spinner
  sleep 5
fi

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Building application...${RESET_FORMAT}"
cd web
(skaffold build --interactive=false \
  --default-repo "$DEFAULT_REPO" \
  --file-output artifacts.json) & spinner
cd ..

echo
cp clouddeploy-config/delivery-pipeline.yaml.template clouddeploy-config/delivery-pipeline.yaml
sed -i "s/targetId: staging/targetId: cd-staging/" clouddeploy-config/delivery-pipeline.yaml
sed -i "s/targetId: prod/targetId: cd-production/" clouddeploy-config/delivery-pipeline.yaml
sed -i "/targetId: test/d" clouddeploy-config/delivery-pipeline.yaml

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Setting deploy region...${RESET_FORMAT}"
(gcloud config set deploy/region "$REGION") & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Applying delivery pipeline...${RESET_FORMAT}"
(gcloud beta deploy apply --file=clouddeploy-config/delivery-pipeline.yaml) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Verifying delivery pipeline...${RESET_FORMAT}"
(gcloud beta deploy delivery-pipelines describe web-app) & spinner

echo
CLUSTERS=("cd-production" "cd-staging")
echo "${BLUE_TEXT}${BOLD_TEXT}Checking cluster status...${RESET_FORMAT}"
for cluster in "${CLUSTERS[@]}"; do
  status=$(gcloud container clusters describe "$cluster" --format="value(status)")
  while [ "$status" != "RUNNING" ]; do
    echo "${YELLOW_TEXT}${BOLD_TEXT}Waiting for $cluster to be RUNNING...${RESET_FORMAT}"
    for i in $(seq 10 -1 1); do
      echo -ne "${YELLOW_TEXT}${BOLD_TEXT}   $i seconds remaining... \r${RESET_FORMAT}"
      sleep 1
    done
    echo -ne "\033[K"
    status=$(gcloud container clusters describe "$cluster" --format="value(status)")
  done
  echo "${GREEN_TEXT}${BOLD_TEXT}$cluster is RUNNING.${RESET_FORMAT}"
done

echo
CONTEXTS=("cd-staging" "cd-production")
echo "${BLUE_TEXT}${BOLD_TEXT}Configuring kubectl contexts...${RESET_FORMAT}"
for CONTEXT in "${CONTEXTS[@]}"; do
  (gcloud container clusters get-credentials "$CONTEXT" --region "$REGION") & spinner
  CURRENT_CONTEXT=$(kubectl config current-context)
  kubectl config rename-context "$CURRENT_CONTEXT" "$CONTEXT" >/dev/null
done

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Applying Kubernetes namespace configuration...${RESET_FORMAT}"
for CONTEXT in "${CONTEXTS[@]}"; do
  (kubectl --context "$CONTEXT" apply -f kubernetes-config/web-app-namespace.yaml) & spinner
done

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Generating Cloud Deploy target configurations...${RESET_FORMAT}"
(envsubst < clouddeploy-config/target-staging.yaml.template > clouddeploy-config/target-cd-staging.yaml) & spinner
(envsubst < clouddeploy-config/target-prod.yaml.template > clouddeploy-config/target-cd-production.yaml) & spinner
(sed -i "s/staging/cd-staging/" clouddeploy-config/target-cd-staging.yaml) & spinner
(sed -i "s/prod/cd-production/" clouddeploy-config/target-cd-production.yaml) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Applying Cloud Deploy targets...${RESET_FORMAT}"
for CONTEXT in "${CONTEXTS[@]}"; do
  (envsubst < "clouddeploy-config/target-$CONTEXT.yaml.template" > "clouddeploy-config/target-$CONTEXT.yaml") & spinner
  (gcloud beta deploy apply --file "clouddeploy-config/target-$CONTEXT.yaml") & spinner
done

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Creating release web-app-001...${RESET_FORMAT}"
(gcloud beta deploy releases create web-app-001 \
  --delivery-pipeline web-app \
  --build-artifacts web/artifacts.json \
  --source web/) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Waiting for staging rollout...${RESET_FORMAT}"
while true; do
  status=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-001 --format="value(state)" | head -n 1)
  if [ "$status" = "SUCCEEDED" ]; then
    echo "${GREEN_TEXT}${BOLD_TEXT}Staging rollout succeeded.${RESET_FORMAT}"
    break
  fi
  echo "${YELLOW_TEXT}${BOLD_TEXT}Current rollout status: $status${RESET_FORMAT}"
  for i in $(seq 10 -1 1); do
    echo -ne "${YELLOW_TEXT}${BOLD_TEXT}   Checking again in $i seconds... \r${RESET_FORMAT}"
    sleep 1
  done
  echo -ne "\033[K"
done

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Promoting release to production approval...${RESET_FORMAT}"
(gcloud beta deploy releases promote \
  --delivery-pipeline web-app \
  --release web-app-001 \
  --quiet) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Waiting for production approval state...${RESET_FORMAT}"
while true; do
  status=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-001 --format="value(state)" | head -n 1)
  if [ "$status" = "PENDING_APPROVAL" ]; then
    echo "${GREEN_TEXT}${BOLD_TEXT}Production approval is pending.${RESET_FORMAT}"
    break
  fi
  echo "${YELLOW_TEXT}${BOLD_TEXT}Current rollout status: $status${RESET_FORMAT}"
  for i in $(seq 10 -1 1); do
    echo -ne "${YELLOW_TEXT}${BOLD_TEXT}   Checking again in $i seconds... \r${RESET_FORMAT}"
    sleep 1
  done
  echo -ne "\033[K"
done

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Approving production rollout...${RESET_FORMAT}"
(gcloud beta deploy rollouts approve web-app-001-to-cd-production-0001 \
  --delivery-pipeline web-app \
  --release web-app-001 \
  --quiet) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Waiting for production rollout...${RESET_FORMAT}"
while true; do
  status=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-001 --format="value(state)" | head -n 1)
  if [ "$status" = "SUCCEEDED" ]; then
    echo "${GREEN_TEXT}${BOLD_TEXT}Production rollout succeeded.${RESET_FORMAT}"
    break
  fi
  echo "${YELLOW_TEXT}${BOLD_TEXT}Current rollout status: $status${RESET_FORMAT}"
  for i in $(seq 10 -1 1); do
    echo -ne "${YELLOW_TEXT}${BOLD_TEXT}   Checking again in $i seconds... \r${RESET_FORMAT}"
    sleep 1
  done
  echo -ne "\033[K"
done

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Ensuring Cloud Build API is enabled...${RESET_FORMAT}"
(gcloud services enable cloudbuild.googleapis.com) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Resetting to tutorial base for the next release...${RESET_FORMAT}"
cd ~/
rm -rf ~/cloud-deploy-tutorials
(git clone https://github.com/GoogleCloudPlatform/cloud-deploy-tutorials.git) & spinner
cd cloud-deploy-tutorials
(git checkout c3cae80 --quiet) & spinner
cd tutorials/base

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Regenerating Skaffold configuration...${RESET_FORMAT}"
(envsubst < clouddeploy-config/skaffold.yaml.template > web/skaffold.yaml) & spinner
cat web/skaffold.yaml

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Building application for the second release...${RESET_FORMAT}"
cd web
(skaffold build --interactive=false \
  --default-repo "$DEFAULT_REPO" \
  --file-output artifacts.json) & spinner
cd ..

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Creating release web-app-002...${RESET_FORMAT}"
(gcloud beta deploy releases create web-app-002 \
  --delivery-pipeline web-app \
  --build-artifacts web/artifacts.json \
  --source web/) & spinner

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Waiting for second staging rollout...${RESET_FORMAT}"
while true; do
  status=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-002 --format="value(state)" | head -n 1)
  if [ "$status" = "SUCCEEDED" ]; then
    echo "${GREEN_TEXT}${BOLD_TEXT}Second staging rollout succeeded.${RESET_FORMAT}"
    break
  fi
  echo "${YELLOW_TEXT}${BOLD_TEXT}Current rollout status: $status${RESET_FORMAT}"
  for i in $(seq 10 -1 1); do
    echo -ne "${YELLOW_TEXT}${BOLD_TEXT}   Checking again in $i seconds... \r${RESET_FORMAT}"
    sleep 1
  done
  echo -ne "\033[K"
done

echo
echo "${BLUE_TEXT}${BOLD_TEXT}Rolling back target cd-staging...${RESET_FORMAT}"
(gcloud deploy targets rollback cd-staging \
  --delivery-pipeline=web-app \
  --quiet) & spinner

echo
echo "${GREEN_TEXT}${BOLD_TEXT}╔════════════════════════════════════════════════════════╗${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}                 Lab completed successfully               ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}╚════════════════════════════════════════════════════════╝${RESET_FORMAT}"
```

</ol>
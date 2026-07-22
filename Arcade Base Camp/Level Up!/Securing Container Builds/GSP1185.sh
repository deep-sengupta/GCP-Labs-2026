#!/bin/bash

BLACK=$'\033[38;5;240m'
RED=$'\033[38;5;203m'
GREEN=$'\033[38;5;84m'
YELLOW=$'\033[38;5;227m'
BLUE=$'\033[38;5;75m'
MAGENTA=$'\033[38;5;141m'
CYAN=$'\033[38;5;51m'
WHITE=$'\033[38;5;255m'

BG_BLACK=$(tput setab 0)
BG_RED=$(tput setab 1)
BG_GREEN=$(tput setab 2)
BG_YELLOW=$(tput setab 3)
BG_BLUE=$(tput setab 4)
BG_MAGENTA=$(tput setab 5)
BG_CYAN=$(tput setab 6)
BG_WHITE=$(tput setab 7)

BOLD=$(tput bold)
RESET=$(tput sgr0)

clear

echo "${MAGENTA}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "              ARTIFACT REGISTRY CONFIGURATION               "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${RESET}"

echo "${CYAN}${BOLD}Loading Google Cloud environment...${RESET}"
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo "${BLUE}${BOLD}Project ID:${RESET} ${WHITE}$PROJECT_ID${RESET}"
echo "${BLUE}${BOLD}Project Number:${RESET} ${WHITE}$PROJECT_NUMBER${RESET}"
echo "${BLUE}${BOLD}Zone:${RESET} ${WHITE}$ZONE${RESET}"
echo "${BLUE}${BOLD}Region:${RESET} ${WHITE}$REGION${RESET}"
echo

echo "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${YELLOW}${BOLD}Enabling Artifact Registry API${RESET}"
echo "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

gcloud services enable artifactregistry.googleapis.com

echo "${GREEN}${BOLD}✔ Artifact Registry API enabled${RESET}"
echo

echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${CYAN}${BOLD}Downloading Sample Repository${RESET}"
echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

git clone https://github.com/GoogleCloudPlatform/java-docs-samples

cd java-docs-samples/container-registry/container-analysis

echo "${GREEN}${BOLD}✔ Repository ready${RESET}"
echo

echo "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${MAGENTA}${BOLD}Creating Maven Repository${RESET}"
echo "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

gcloud artifacts repositories create container-dev-java-repo \
    --repository-format=maven \
    --location=$REGION \
    --description="Java package repository for Container Dev Workshop"

echo "${GREEN}${BOLD}✔ Repository created${RESET}"

echo "${BLUE}${BOLD}Displaying repository information...${RESET}"

gcloud artifacts repositories describe container-dev-java-repo \
    --location=$REGION

echo "${GREEN}${BOLD}✔ Repository verified${RESET}"
echo

echo "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${YELLOW}${BOLD}Creating Remote Repository${RESET}"
echo "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

gcloud artifacts repositories create maven-central-cache \
    --project=$PROJECT_ID \
    --repository-format=maven \
    --location=$REGION \
    --description="Remote repository for Maven Central caching" \
    --mode=remote-repository \
    --remote-repo-config-desc="Maven Central" \
    --remote-mvn-repo=MAVEN-CENTRAL

echo "${GREEN}${BOLD}✔ Remote repository created${RESET}"
echo

echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${CYAN}${BOLD}Preparing Virtual Repository${RESET}"
echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

cat > ./policy.json << EOF
[
  {
    "id": "private",
    "repository": "projects/${PROJECT_ID}/locations/$REGION/repositories/container-dev-java-repo",
    "priority": 100
  },
  {
    "id": "central",
    "repository": "projects/${PROJECT_ID}/locations/$REGION/repositories/maven-central-cache",
    "priority": 80
  }
]
EOF

echo "${GREEN}${BOLD}✔ Policy file generated${RESET}"

echo "${BLUE}${BOLD}Creating virtual Maven repository...${RESET}"

gcloud artifacts repositories create virtual-maven-repo \
    --project=${PROJECT_ID} \
    --repository-format=maven \
    --mode=virtual-repository \
    --location=$REGION \
    --description="Virtual Maven Repo" \
    --upstream-policy-file=./policy.json

echo "${GREEN}${BOLD}✔ Virtual repository created${RESET}"
echo

echo "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${GREEN}${BOLD}                  LAB COMPLETED SUCCESSFULLY                 ${RESET}"
echo "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
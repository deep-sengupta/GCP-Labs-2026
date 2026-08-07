# Continuous Delivery with Google Cloud Deploy

<h2>📋 Steps</h2>

<ol>
  <li>Open <b>Cloud Shell</b>.</li>
  <li>Paste the provided script into <b>Cloud Shell</b> and run it.</li>

```bash
#!/bin/bash
set -euo pipefail

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
RESET=$(tput sgr0)

banner() {
  clear
  printf "\n"
}

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'

  printf "${CYAN}Working${RESET} "
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c] " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep "$delay"
    printf "\b\b\b\b\b"
  done
  printf "\b\b\b\b\b${GREEN}Done${RESET}\n"
}

banner

sleep 3 &
spinner $!

export REGION
REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

export PROJECT_ID
PROJECT_ID=$(gcloud config get-value project)

export PROJECT_NUMBER
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

gcloud config set compute/region "$REGION"

gcloud services enable container.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com containeranalysis.googleapis.com

gcloud artifacts repositories create my-repository \
  --repository-format=docker \
  --location="$REGION" || true

gcloud container clusters create hello-cloudbuild --num-nodes 1 --region "$REGION" || true

curl -sS https://webi.sh/gh | sh
gh auth login

export GITHUB_USERNAME
GITHUB_USERNAME=$(gh api user -q ".login")

git config --global user.name "$GITHUB_USERNAME"
git config --global user.email "${USER_EMAIL:-$(gh api user -q '.email // empty')}"

echo "$GITHUB_USERNAME"
echo "${USER_EMAIL:-}"

gh repo create hello-cloudbuild-app --private || true
gh repo create hello-cloudbuild-env --private || true

cd ~
rm -rf hello-cloudbuild-app
mkdir -p hello-cloudbuild-app
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-app
cd ~/hello-cloudbuild-app

sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl

git init
git config credential.helper gcloud.sh
git remote add google "https://github.com/${GITHUB_USERNAME}/hello-cloudbuild-app" || true
git branch -M master
git add .
git commit -m "initial commit" || true

COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .

git add .
git commit -m "Type Any Commit Message here" || true
git push google master || true

cd ~
rm -rf workingdir
mkdir -p workingdir
cd workingdir

ssh-keygen -t rsa -b 4096 -N '' -f id_github -C "${USER_EMAIL:-}" >/dev/null

gcloud secrets create ssh_key_secret --replication-policy="automatic" || true
gcloud secrets versions add ssh_key_secret --data-file=id_github

SSH_KEY_CONTENT=$(cat ~/workingdir/id_github.pub)

gh api --method POST -H "Accept: application/vnd.github.v3+json" \
  /repos/${GITHUB_USERNAME}/hello-cloudbuild-env/keys \
  -f title="SSH_KEY" \
  -f key="$SSH_KEY_CONTENT" \
  -F read_only=false || true

rm -f id_github*

gcloud projects add-iam-policy-binding "$PROJECT_NUMBER" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role=roles/secretmanager.secretAccessor

gcloud projects add-iam-policy-binding "$PROJECT_NUMBER" \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role=roles/container.developer

cd ~
rm -rf hello-cloudbuild-env
mkdir -p hello-cloudbuild-env
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-env

cd hello-cloudbuild-env
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl

ssh-keyscan -t rsa github.com > known_hosts.github
chmod +x known_hosts.github

git init
git config credential.helper gcloud.sh
git remote add google "https://github.com/${GITHUB_USERNAME}/hello-cloudbuild-env" || true
git branch -M master
git add .
git commit -m "initial commit" || true
git push google master || true

git checkout -b production
rm -f cloudbuild.yaml

curl -LO raw.githubusercontent.com/deep-sengupta/GCP-Labs-2026/refs/heads/master/Arcade%20Trail/Continuous%20Delivery/Continuous%20Delivery%20with%20Google%20Cloud%20Deploy/env-cloudbuild.yaml
mv -f env-cloudbuild.yaml cloudbuild.yaml

sed -i "s/REGION-/$REGION/g" cloudbuild.yaml
sed -i "s/GITHUB-USERNAME/${GITHUB_USERNAME}/g" cloudbuild.yaml

git add .
git commit -m "Create cloudbuild.yaml for deployment" || true

git checkout -b candidate
git push google production || true
git push google candidate || true

cd ~/hello-cloudbuild-app
ssh-keyscan -t rsa github.com > known_hosts.github
chmod +x known_hosts.github

git add .
git commit -m "Adding known_host file." || true
git push google master || true

rm -f cloudbuild.yaml

curl -LO raw.githubusercontent.com/deep-sengupta/GCP-Labs-2026/refs/heads/master/Arcade%20Trail/Continuous%20Delivery/Continuous%20Delivery%20with%20Google%20Cloud%20Deploy/app-cloudbuild.yaml
mv -f app-cloudbuild.yaml cloudbuild.yaml

sed -i "s/REGION/$REGION/g" cloudbuild.yaml
sed -i "s/GITHUB-USERNAME/${GITHUB_USERNAME}/g" cloudbuild.yaml

git add cloudbuild.yaml
git commit -m "Trigger CD pipeline" || true
git push google master || true
```

  <li>When prompted, sign in using your <b>personal GitHub account</b>.</li>
  <li>If any GitHub authorization or confirmation appears, complete it to continue.</li>
  <li>Follow the remaining instructions in the lab to complete all the tasks.</li>
  <li>Click <b>Check my progress</b> to verify the lab completion.</li>
</ol>

# Configuring IAM Permissions with gcloud

<h2>📁 Steps</h2>

<ol>
<li>Open <b>Cloud Shell</b>.</li>
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

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

echo
echo "${BOLD_TEXT}${CYAN_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${BOLD_TEXT}${WHITE_TEXT}              GOOGLE CLOUD IAM LAB SETUP${RESET_FORMAT}"
echo "${BOLD_TEXT}${CYAN_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

gcloud auth login --quiet

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Setting Compute Zone & Region${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Configuring Compute Settings${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE"

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Creating lab-1 VM instance${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud compute instances create lab-1 \
--zone "$ZONE" \
--machine-type=e2-standard-2

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Selecting a new zone in same region${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

export NEWZONE=$(gcloud compute zones list \
--filter="name~'^$REGION'" \
--format="value(name)" | grep -v "^$ZONE$" | head -n 1)

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Setting new zone in gcloud config${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config set compute/zone "$NEWZONE"

function check_progress {
while true; do
echo
echo "${BOLD_TEXT}${MAGENTA_TEXT}┌──────────────────────────────────────────────────────────┐${RESET_FORMAT}"
echo -n "${BOLD_TEXT}${WHITE_TEXT}│ Have you checked your progress for Task 1 ? (Y/N): ${RESET_FORMAT}"
read -r user_input
echo "${BOLD_TEXT}${MAGENTA_TEXT}└──────────────────────────────────────────────────────────┘${RESET_FORMAT}"

if [[ "$user_input" == "Y" || "$user_input" == "y" ]]; then
echo
echo "${BOLD_TEXT}${GREEN_TEXT}✓ Great! Proceeding to the next steps...${RESET_FORMAT}"
echo
break
elif [[ "$user_input" == "N" || "$user_input" == "n" ]]; then
echo
echo "${BOLD_TEXT}${RED_TEXT}✗ Please check your progress for Task 1 and then press Y to continue.${RESET_FORMAT}"
else
echo
echo "${BOLD_TEXT}${YELLOW_TEXT}! Invalid input. Please enter Y or N.${RESET_FORMAT}"
fi
done
}

check_progress

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Creating gcloud configuration for user2${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config configurations create user2 --quiet

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Authenticating user2${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud auth login --no-launch-browser --quiet

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Configuring user2 project, zone and region${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config set project "$(gcloud config get-value project --configuration=default)" --configuration=user2
gcloud config set compute/zone "$(gcloud config get-value compute/zone --configuration=default)" --configuration=user2
gcloud config set compute/region "$(gcloud config get-value compute/region --configuration=default)" --configuration=user2

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Switching back to default config${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config configurations activate default

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Installing dependencies${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

sudo yum -y install epel-release
sudo yum -y install jq

echo

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Collecting PROJECTID2, USERID2 and ZONE2${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

get_and_export_values() {
echo -n "${BOLD_TEXT}${CYAN_TEXT}Enter the PROJECTID2: ${RESET_FORMAT}"
read PROJECTID2
echo

echo -n "${BOLD_TEXT}${CYAN_TEXT}Enter the USERID2: ${RESET_FORMAT}"
read USERID2
echo

echo -n "${BOLD_TEXT}${CYAN_TEXT}Enter the ZONE2: ${RESET_FORMAT}"
read ZONE2
echo

export PROJECTID2
export USERID2
export ZONE2

echo "export PROJECTID2=$PROJECTID2" >> ~/.bashrc
echo "export USERID2=$USERID2" >> ~/.bashrc
echo "export ZONE2=$ZONE2" >> ~/.bashrc
}

get_and_export_values

echo

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Granting viewer role to user2${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

. ~/.bashrc

gcloud projects add-iam-policy-binding "$PROJECTID2" \
--member="user:$USERID2" \
--role="roles/viewer"

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Switching to user2 config${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config configurations activate user2

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Setting project for user2${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config set project "$PROJECTID2"

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Switching to default config${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config configurations activate default

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Creating custom IAM role devops${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud iam roles create devops \
--project "$PROJECTID2" \
--permissions "compute.instances.create,compute.instances.delete,compute.instances.start,compute.instances.stop,compute.instances.update,compute.disks.create,compute.subnetworks.use,compute.subnetworks.useExternalIp,compute.instances.setMetadata,compute.instances.setServiceAccount"

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Assigning IAM roles to user2${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud projects add-iam-policy-binding "$PROJECTID2" \
--member="user:$USERID2" \
--role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding "$PROJECTID2" \
--member="user:$USERID2" \
--role="projects/$PROJECTID2/roles/devops"

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Switching to user2 config${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config configurations activate user2

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Creating lab-2 VM instance${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud compute instances create lab-2 \
--zone "$ZONE2" \
--machine-type=e2-standard-2

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Switching to default config${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config configurations activate default

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Setting project to PROJECTID2${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud config set project "$PROJECTID2"

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Creating devops service account${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud iam service-accounts create devops \
--display-name="devops" || true

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Setting service account email${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

SA="devops@${PROJECTID2}.iam.gserviceaccount.com"

gcloud iam service-accounts describe "$SA" \
--project="$PROJECTID2" \
--format="value(email)"

echo
echo "${BOLD_TEXT}${MAGENTA_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${BOLD_TEXT}${WHITE_TEXT}        APPLYING REQUIRED SERVICE ACCOUNT BINDINGS${RESET_FORMAT}"
echo "${BOLD_TEXT}${MAGENTA_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

echo "${BOLD_TEXT}${BLUE_TEXT}▶ Binding roles/iam.serviceAccountUser${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud projects add-iam-policy-binding "$PROJECTID2" \
--member="serviceAccount:$SA" \
--role="roles/iam.serviceAccountUser" \
--quiet

echo
echo "${BOLD_TEXT}${GREEN_TEXT}✓ roles/iam.serviceAccountUser binding applied${RESET_FORMAT}"

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Binding roles/compute.instanceAdmin${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud projects add-iam-policy-binding "$PROJECTID2" \
--member="serviceAccount:$SA" \
--role="roles/compute.instanceAdmin" \
--quiet

echo
echo "${BOLD_TEXT}${GREEN_TEXT}✓ roles/compute.instanceAdmin binding applied${RESET_FORMAT}"

echo
echo "${BOLD_TEXT}${MAGENTA_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${BOLD_TEXT}${WHITE_TEXT}        VERIFYING REQUIRED SERVICE ACCOUNT BINDINGS${RESET_FORMAT}"
echo "${BOLD_TEXT}${MAGENTA_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

IAM_POLICY=$(gcloud projects get-iam-policy "$PROJECTID2" --format=json)

if echo "$IAM_POLICY" | jq -e --arg SA "$SA" \
'.bindings[] | select(.role=="roles/iam.serviceAccountUser") | .members[] | select(.=="serviceAccount:"+$SA)' >/dev/null; then
echo "${BOLD_TEXT}${GREEN_TEXT}✓ Service account has roles/iam.serviceAccountUser${RESET_FORMAT}"
else
echo "${BOLD_TEXT}${RED_TEXT}✗ roles/iam.serviceAccountUser binding not found${RESET_FORMAT}"
exit 1
fi

if echo "$IAM_POLICY" | jq -e --arg SA "$SA" \
'.bindings[] | select(.role=="roles/compute.instanceAdmin") | .members[] | select(.=="serviceAccount:"+$SA)' >/dev/null; then
echo "${BOLD_TEXT}${GREEN_TEXT}✓ Service account has roles/compute.instanceAdmin${RESET_FORMAT}"
else
echo "${BOLD_TEXT}${RED_TEXT}✗ roles/compute.instanceAdmin binding not found${RESET_FORMAT}"
exit 1
fi

echo
echo "${BOLD_TEXT}${GREEN_TEXT}✓ BOTH REQUIRED SERVICE ACCOUNT TASKS ARE COMPLETE${RESET_FORMAT}"
echo

echo
echo "${BOLD_TEXT}${BLUE_TEXT}▶ Creating lab-3 VM instance using service account${RESET_FORMAT}"
echo "${CYAN_TEXT}────────────────────────────────────────────────────────────${RESET_FORMAT}"

gcloud compute instances create lab-3 \
--zone "$ZONE2" \
--machine-type=e2-standard-2 \
--service-account "$SA" \
--scopes "https://www.googleapis.com/auth/compute"

echo

cd

remove_files() {
for file in *; do
if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* ]]; then
if [[ -f "$file" ]]; then
rm "$file"
echo "${BOLD_TEXT}${GREEN_TEXT}File removed: $file${RESET_FORMAT}"
fi
fi
done
}

remove_files
```

</ol>
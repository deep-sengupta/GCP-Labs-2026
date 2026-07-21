#!/bin/bash

BLACK_TEXT=$'\033[38;5;240m'
RED_TEXT=$'\033[38;5;203m'
GREEN_TEXT=$'\033[38;5;84m'
YELLOW_TEXT=$'\033[38;5;227m'
BLUE_TEXT=$'\033[38;5;75m'
MAGENTA_TEXT=$'\033[38;5;141m'
CYAN_TEXT=$'\033[38;5;51m'
WHITE_TEXT=$'\033[38;5;255m'
TEAL=$'\033[38;5;44m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'
BLINK_TEXT=$'\033[5m'
NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'
REVERSE_TEXT=$'\033[7m'

clear

echo "${MAGENTA_TEXT}${BOLD_TEXT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                GKE MULTI-TENANT CLUSTER SETUP                  "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${RESET_FORMAT}"

echo "${CYAN_TEXT}${BOLD_TEXT}Downloading lab files...${RESET_FORMAT}"
gsutil -m cp -r gs://spls/gsp766/gke-qwiklab ~

cd ~/gke-qwiklab

echo "${CYAN_TEXT}${BOLD_TEXT}Configuring cluster credentials...${RESET_FORMAT}"
gcloud config set compute/zone ${ZONE} && gcloud container clusters get-credentials multi-tenant-cluster

echo "${YELLOW_TEXT}${BOLD_TEXT}Creating namespaces...${RESET_FORMAT}"
kubectl create namespace team-a && \
kubectl create namespace team-b

echo "${GREEN_TEXT}${BOLD_TEXT}Deploying application pods...${RESET_FORMAT}"
kubectl run app-server --image=centos --namespace=team-a -- sleep infinity && \
kubectl run app-server --image=centos --namespace=team-b -- sleep infinity

echo "${BLUE_TEXT}${BOLD_TEXT}Displaying Team-A pod details...${RESET_FORMAT}"
kubectl describe pod app-server --namespace=team-a

echo "${CYAN_TEXT}${BOLD_TEXT}Switching context to Team-A...${RESET_FORMAT}"
kubectl config set-context --current --namespace=team-a

echo "${MAGENTA_TEXT}${BOLD_TEXT}Assigning IAM permissions...${RESET_FORMAT}"
gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
--member=serviceAccount:team-a-dev@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com \
--role=roles/container.clusterViewer

echo "${GREEN_TEXT}${BOLD_TEXT}Creating Kubernetes roles...${RESET_FORMAT}"
kubectl create role pod-reader \
--resource=pods --verb=watch --verb=get --verb=list

kubectl create -f developer-role.yaml

echo "${GREEN_TEXT}${BOLD_TEXT}Creating role binding...${RESET_FORMAT}"
kubectl create rolebinding team-a-developers \
--role=developer --user=team-a-dev@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com

echo "${YELLOW_TEXT}${BOLD_TEXT}Generating service account key...${RESET_FORMAT}"
gcloud iam service-accounts keys create /tmp/key.json --iam-account team-a-dev@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com

echo "${CYAN_TEXT}${BOLD_TEXT}Refreshing cluster credentials...${RESET_FORMAT}"
gcloud container clusters get-credentials multi-tenant-cluster --zone ${ZONE} --project ${GOOGLE_CLOUD_PROJECT}

echo "${MAGENTA_TEXT}${BOLD_TEXT}Creating resource quota...${RESET_FORMAT}"
kubectl create quota test-quota \
--hard=count/pods=2,count/services.loadbalancers=1 --namespace=team-a

echo "${GREEN_TEXT}${BOLD_TEXT}Launching additional pods...${RESET_FORMAT}"
kubectl run app-server-2 --image=centos --namespace=team-a -- sleep infinity

kubectl run app-server-3 --image=centos --namespace=team-a -- sleep infinity

sleep 20

echo "${BLUE_TEXT}${BOLD_TEXT}Updating quota limits...${RESET_FORMAT}"
kubectl get quota test-quota --namespace=team-a -o yaml | \
sed 's/count\/pods: "2"/count\/pods: "6"/' | \
kubectl apply -f -

echo "${CYAN_TEXT}${BOLD_TEXT}Applying CPU and memory quota...${RESET_FORMAT}"
kubectl create -f cpu-mem-quota.yaml

echo "${CYAN_TEXT}${BOLD_TEXT}Deploying demo pod...${RESET_FORMAT}"
kubectl create -f cpu-mem-demo-pod.yaml --namespace=team-a

echo "${GREEN_TEXT}${BOLD_TEXT}Displaying quota information...${RESET_FORMAT}"
kubectl describe quota cpu-mem-quota --namespace=team-a

echo "${MAGENTA_TEXT}${BOLD_TEXT}Enabling usage metering...${RESET_FORMAT}"
gcloud container clusters \
update multi-tenant-cluster --zone ${ZONE} \
--resource-usage-bigquery-dataset cluster_dataset

export GCP_BILLING_EXPORT_TABLE_FULL_PATH=${GOOGLE_CLOUD_PROJECT}.billing_dataset.gcp_billing_export_v1_xxxx
export USAGE_METERING_DATASET_ID=cluster_dataset
export COST_BREAKDOWN_TABLE_ID=usage_metering_cost_breakdown

export USAGE_METERING_QUERY_TEMPLATE=~/gke-qwiklab/usage_metering_query_template.sql
export USAGE_METERING_QUERY=cost_breakdown_query.sql
export USAGE_METERING_START_DATE=2020-10-26

echo "${YELLOW_TEXT}${BOLD_TEXT}Generating scheduled query...${RESET_FORMAT}"
sed \
-e "s/\${fullGCPBillingExportTableID}/$GCP_BILLING_EXPORT_TABLE_FULL_PATH/" \
-e "s/\${projectID}/$GOOGLE_CLOUD_PROJECT/" \
-e "s/\${datasetID}/$USAGE_METERING_DATASET_ID/" \
-e "s/\${startDate}/$USAGE_METERING_START_DATE/" \
"$USAGE_METERING_QUERY_TEMPLATE" \
> "$USAGE_METERING_QUERY"

echo "${GREEN_TEXT}${BOLD_TEXT}Creating scheduled BigQuery job...${RESET_FORMAT}"
bq query \
--project_id=$GOOGLE_CLOUD_PROJECT \
--use_legacy_sql=false \
--destination_table=$USAGE_METERING_DATASET_ID.$COST_BREAKDOWN_TABLE_ID \
--schedule='every 24 hours' \
--display_name="GKE Usage Metering Cost Breakdown Scheduled Query" \
--replace=true \
"$(cat $USAGE_METERING_QUERY)"

echo
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}                    LAB SETUP COMPLETED                         ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
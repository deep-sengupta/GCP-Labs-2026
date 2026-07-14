# Cloud Run Functions: Qwik Start

<h2>📋 Steps</h2>

<ol>

<li>Activate <b>Cloud Shell</b>.</li>

<li>Authenticate with Google Cloud:</li>

```bash
gcloud auth login
```

<ul>
  <li>Enter <b>Y</b> when prompted.</li>
  <li>Open the generated authentication link.</li>
  <li>Copy the verification code.</li>
  <li>Paste the verification code into Cloud Shell.</li>
</ul>

<li>Set your active project:</li>

```bash
gcloud config set project PROJECT_ID
```

<li>Enable the required APIs:</li>

```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com
```
```bash
gcloud services enable cloudaicompanion.googleapis.com
```

<li>Create the HTTP function project:</li>

```bash
mkdir ~/hello-http && cd $_
touch index.js package.json
```

<li>Add the provided <code>index.js</code> and <code>package.json</code> code using the Cloud Shell Editor.</li>

<li>Deploy the HTTP function:</li>

```bash
gcloud functions deploy nodejs-http-function \
  --gen2 \
  --runtime nodejs22 \
  --entry-point helloWorld \
  --source . \
  --region Region \
  --trigger-http \
  --timeout 600s \
  --max-instances 1
```

<li>Test the HTTP function:</li>

```bash
gcloud functions call nodejs-http-function \
  --gen2 --region Region
```

<li>Grant Cloud Storage Pub/Sub permissions:</li>

```bash
PROJECT_NUMBER=$(gcloud projects list --filter="project_id:PROJECT_ID" --format='value(project_number)')
SERVICE_ACCOUNT=$(gsutil kms serviceaccount -p $PROJECT_NUMBER)

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member serviceAccount:$SERVICE_ACCOUNT \
  --role roles/pubsub.publisher
```

<li>Create the Cloud Storage function project:</li>

```bash
mkdir ~/hello-storage && cd $_
touch index.js package.json
```

<li>Add the provided <code>index.js</code> and <code>package.json</code> code.</li>

<li>Create a Cloud Storage bucket:</li>

```bash
BUCKET="gs://gcf-gen2-storage-PROJECT_ID"
gsutil mb -l Region $BUCKET
```

<li>Deploy the Cloud Storage function:</li>

```bash
gcloud functions deploy nodejs-storage-function \
  --gen2 \
  --runtime nodejs22 \
  --entry-point helloStorage \
  --source . \
  --region Region \
  --trigger-bucket $BUCKET \
  --trigger-location Region \
  --max-instances 1
```

<li>Test the Storage function:</li>

```bash
echo "Hello World" > random.txt
gsutil cp random.txt $BUCKET/random.txt
```

<li>View the Storage function logs:</li>

```bash
gcloud functions logs read nodejs-storage-function \
  --region Region --gen2 --limit=100 --format="value(log)"
```

<li>Enable Audit Logs for the <b>Compute Engine API</b> from <b>IAM & Admin → Audit Logs</b>.</li>

<li>Grant the Eventarc Event Receiver role:</li>

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com \
  --role roles/eventarc.eventReceiver
```

<li>Clone the sample repository:</li>

```bash
cd ~
git clone https://github.com/GoogleCloudPlatform/eventarc-samples.git
```

<li>Navigate to the sample project:</li>

```bash
cd ~/eventarc-samples/gce-vm-labeler/gcf/nodejs
```

<li>Deploy the Audit Logs function:</li>

```bash
gcloud functions deploy gce-vm-labeler \
  --gen2 \
  --runtime nodejs22 \
  --entry-point labelVmCreation \
  --source . \
  --region Region \
  --trigger-event-filters="type=google.cloud.audit.log.v1.written,serviceName=compute.googleapis.com,methodName=beta.compute.instances.insert" \
  --trigger-location Region \
  --max-instances 1
```

<li>Create a Compute Engine VM named <code>instance-1</code>.</li>

<li>Verify the VM:</li>

```bash
gcloud compute instances describe instance-1 --zone Zone
```

<li>Delete the VM:</li>

```bash
gcloud compute instances delete instance-1 --zone Zone
```

<li>Create the revision deployment project:</li>

```bash
mkdir ~/hello-world-colored && cd $_
touch main.py requirements.txt
```

<li>Add the provided <code>main.py</code> code.</li>

<li>Deploy the first revision:</li>

```bash
COLOR=orange

gcloud functions deploy hello-world-colored \
  --gen2 \
  --runtime python311 \
  --entry-point hello_world \
  --source . \
  --region Region \
  --trigger-http \
  --allow-unauthenticated \
  --update-env-vars COLOR=$COLOR \
  --max-instances 1
```

<li>Edit the function in the Cloud Run console and change the <code>COLOR</code> environment variable to <b>yellow</b>, then deploy a new revision.</li>

<li>Create the minimum instances project:</li>

```bash
mkdir ~/min-instances && cd $_
touch main.go go.mod
```

<li>Add the provided <code>main.go</code> and <code>go.mod</code> files.</li>

<li>Deploy the Go function:</li>

```bash
gcloud functions deploy slow-function \
  --gen2 \
  --runtime go123 \
  --entry-point HelloWorld \
  --source . \
  --region Region \
  --trigger-http \
  --allow-unauthenticated \
  --max-instances 4
```

<li>Test the function:</li>

```bash
gcloud functions call slow-function \
  --gen2 --region Region
```

<li>From the Cloud Run console, edit the function and set:</li>

<ul>
  <li><b>Minimum instances:</b> 1</li>
  <li><b>Maximum instances:</b> 4</li>
</ul>

<li>Test the function again:</li>

```bash
gcloud functions call slow-function \
  --gen2 --region Region
```

<li>Install the benchmarking tool:</li>

```bash
sudo apt install hey
```

<li>Retrieve the function URL:</li>

```bash
SLOW_URL=$(gcloud functions describe slow-function \
--region Region \
--gen2 \
--format="value(serviceConfig.uri)")
```

<li>Benchmark the function:</li>

```bash
hey -n 10 -c 10 $SLOW_URL
```

<li>Delete the function:</li>

```bash
gcloud run services delete slow-function --region Region
```

<li>Deploy the concurrent function:</li>

```bash
gcloud functions deploy slow-concurrent-function \
  --gen2 \
  --runtime go123 \
  --entry-point HelloWorld \
  --source . \
  --region Region \
  --trigger-http \
  --allow-unauthenticated \
  --min-instances 1 \
  --max-instances 4
```

<li>In the Cloud Run console, configure:</li>

<ul>
  <li><b>CPU:</b> 1</li>
  <li><b>Maximum concurrent requests:</b> 100</li>
  <li><b>Maximum instances:</b> 4</li>
</ul>

<li>Retrieve the concurrent function URL:</li>

```bash
SLOW_CONCURRENT_URL=$(gcloud functions describe slow-concurrent-function \
--region Region \
--gen2 \
--format="value(serviceConfig.uri)")
```

<li>Run the concurrency benchmark:</li>

```bash
hey -n 10 -c 10 $SLOW_CONCURRENT_URL
```

</ol>
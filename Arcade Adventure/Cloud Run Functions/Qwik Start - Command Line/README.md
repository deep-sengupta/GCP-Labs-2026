# Cloud Run Functions: Qwik Start - Command Line

<h2>📋 Steps</h2>

<ol>

<li>Open <b>Cloud Shell</b>.</li>

<li>Set the default Cloud Run region.</li>

```bash
gcloud config set run/region REGION
```

<li>Create a new project directory and navigate into it.</li>

```bash
mkdir gcf_hello_world && cd $_
```

<li>Create and edit the <code>index.js</code> file.</li>

```bash
nano index.js
```

<li>Paste the following code into <code>index.js</code>.</li>

```javascript
const functions = require('@google-cloud/functions-framework');

functions.cloudEvent('helloPubSub', cloudEvent => {
  const base64name = cloudEvent.data.message.data;

  const name = base64name
    ? Buffer.from(base64name, 'base64').toString()
    : 'World';

  console.log(`Hello, ${name}!`);
});
```

<li>Save the file and exit the editor.</li>

<li>Create and edit the <code>package.json</code> file.</li>

```bash
nano package.json
```

<li>Paste the following configuration.</li>

```json
{
  "name": "gcf_hello_world",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
```

<li>Save the file and exit the editor.</li>

<li>Install the required dependencies.</li>

```bash
npm install
```

<li>Deploy the Cloud Run function.</li>

```bash
gcloud functions deploy nodejs-pubsub-function \
  --gen2 \
  --runtime=nodejs_version \
  --region=REGION \
  --source=. \
  --entry-point=helloPubSub \
  --trigger-topic cf-demo \
  --stage-bucket PROJECT_ID-bucket \
  --service-account cloudfunctionsa@PROJECT_ID.iam.gserviceaccount.com \
  --allow-unauthenticated
```

<li>If prompted about <code>serviceAccountTokenCreator</code>, enter <b>n</b>.</li>

<li>Verify the deployment status.</li>

```bash
gcloud functions describe nodejs-pubsub-function \
  --region=REGION
```

<li>Confirm that the function status is <code>ACTIVE</code>.</li>

</ol>
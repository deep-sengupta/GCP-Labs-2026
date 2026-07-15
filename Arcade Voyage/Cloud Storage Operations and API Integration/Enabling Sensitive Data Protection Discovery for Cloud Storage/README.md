# Enabling Sensitive Data Protection Discovery for Cloud Storage

<h2>📋 Steps</h2>

<ol>

<li>Open the <b>Google Cloud Console</b>.</li>

<li>
Navigate to:
<ul>
<li><b>☰ Navigation Menu → Security → Sensitive Data Protection</b></li>
</ul>
</li>

<li>Open the <b>Discovery</b> tab.</li>

<li>Under <b>Cloud Storage</b>, click <b>Enable</b>.</li>

<li>
Configure the discovery settings:
<ul>
<li>Enable <b>Publish to Security Command Center</b>.</li>
<li>Enable <b>Save data profile copies to BigQuery</b>.</li>
</ul>
</li>

<li>Configure the BigQuery destination:</li>

| Property | Value |
| :------- | :---- |
| **Dataset ID** | `cloudstorage_discovery` |
| **Table ID** | `data_profiles` |

<li>Set the display name to <code>Cloud Storage Discovery</code>.</li>

<li>Save the discovery configuration.</li>

<li>Open <b>Cloud Shell</b>.</li>

<li>Authenticate with Google Cloud:</li>

```bash
gcloud auth login
```

<ul>
<li>Select <b>Y</b> when prompted.</li>
<li>Open the authentication link.</li>
<li>Copy the verification code.</li>
<li>Paste the verification code into Cloud Shell.</li>
</ul>

<li>Run the command provided in this repository to complete the lab.</li>

</ol>
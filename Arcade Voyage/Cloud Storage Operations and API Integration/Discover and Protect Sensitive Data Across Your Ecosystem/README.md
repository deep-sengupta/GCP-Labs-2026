# Discover and Protect Sensitive Data Across Your Ecosystem: Challenge Lab

<h2>📋 Steps</h2>

<ol>

<li>Open the <b>Sensitive Data Protection</b> page.</li>

<li>Enable Sensitive Data Protection for <b>Cloud Storage</b>.</li>

<li>Configure the following settings:</li>

| Property | Value |
| :------- | :---- |
| **Dataset ID** | `cs_discovery` |
| **Table ID** | `cs_data_profiles` |

<li>Click <b>Create</b>.</li>

<li>Open <b>Cloud Shell</b> and run the following commands:</li>

```bash
curl -LO <URL>

sudo chmod +x GSP522.sh

./GSP522.sh
```

<li>Navigate to <b>IAM & Admin → IAM</b>.</li>

<li>Edit the permissions for <b>Username 2</b>.</li>

<li>Replace the <b>Viewer</b> role with <b>Browser</b>.</li>

<li>Keep the <b>BigQuery Data Viewer</b> role.</li>

<li>Add the following IAM condition:</li>

| Property | Value |
| :------- | :---- |
| **Condition Title** | `No SPII Access Only` |
| **Condition Type** | `Tag has value` |
| **Value Path** | `____/SPII/No` |

<li>Save the updated IAM policy.</li>

<li>Open <b>BigQuery</b>.</li>

<li>Locate the dataset named <code>orders</code>.</li>

<li>Tag the dataset with:</li>

| Tag | Value |
| :-- | :---- |
| **SPII** | `No` |

<li>Search for <b>Workbench</b> from the Google Cloud Console.</li>

<li>Open <b>JupyterLab</b>.</li>

<li>Open a new <b>Terminal</b>.</li>

<li>Run the following commands:</li>

```bash
rm deidentify-model-response-challenge-lab.ipynb

curl -LO <URL>
```

<li>Wait until the Jupyter kernel status changes to <b>Idle</b>.</li>

</ol>
# Enabling Sensitive Data Protection Discovery for BigQuery

<h2>📋 Steps</h2>

<ol>

<li>Open the <b>Google Cloud Console</b>.</li>

<li>
Navigate to:
<ul>
<li><b>☰ Navigation Menu → Security → Sensitive Data Protection</b></li>
</ul>
</li>

<li>Select the <b>Discovery</b> tab.</li>

<li>Under <b>BigQuery</b>, click <b>Enable</b>.</li>

<li>Configure the discovery scan:</li>

| Setting | Value |
| :------ | :---- |
| **Display Name** | `BigQuery Discovery` |
| **Publish to Security Command Center** | Enabled |
| **Save data profile copies to BigQuery** | Enabled |
| **Dataset ID** | `bq_discovery` |
| **Table ID** | `data_profiles` |
| **Create scan in paused mode** | Enabled |

<li>Click <b>Create</b>, then click <b>Create configuration</b>.</li>

<li>Open <b>Cloud Shell</b> and run the provided setup commands:</li>

```bash
curl -LO https://raw.githubusercontent.com/deep-sengupta/GCP-Labs-2026/refs/heads/master/Arcade%20Voyage/Cloud%20Storage%20Operations%20and%20API%20Integration/Enabling%20Sensitive%20Data%20Protection%20Discovery%20for%20BigQuery/GSP1282.sh

sudo chmod +x *.sh

./*.sh
```

<li>Return to <b>Sensitive Data Protection → Discovery</b>.</li>

<li>Under <b>Scan Configurations</b>, locate <b>BigQuery Discovery</b>.</li>

<li>Click <b>⋮ → Edit</b>.</li>

<li>Enable <b>Tag resources</b> and configure the following tags:</li>

| Resource | Tag Value |
| :------- | :-------- |
| **High Sensitivity** | `____/sensitivity-level/high` |
| **Moderate Sensitivity** | `____/sensitivity-level/moderate` |
| **Low Sensitivity** | `____/sensitivity-level/low` |
| **Unknown Sensitivity** | `____/sensitivity-level/unknown` |

<li>Click <b>Save</b>, then <b>Confirm edit</b>.</li>

<li>Click <b>Resume Scan</b>.</li>

<li>Navigate to <b>☰ Navigation Menu → IAM & Admin → IAM</b>.</li>

<li>Edit the permissions for <b>Username 2</b>.</li>

<li>Remove the <b>Viewer</b> role.</li>

<li>Add the following roles:</li>

| Role | Configuration |
| :--- | :------------ |
| **Browser** | Basic → Browser |
| **BigQuery Data Viewer** | Add IAM Condition |

<li>Configure the IAM condition:</li>

| Setting | Value |
| :------ | :---- |
| **Title** | `Low Sensitivity Data Access Only` |
| **Condition Type** | Tag |
| **Operator** | has value |
| **Value Path** | `____/sensitivity-level/low` |

<li>Click <b>Save</b>.</li>

<li>Navigate to <b>☰ Navigation Menu → BigQuery</b>.</li>

<li>Open the <b>damaged_car_image_info</b> dataset.</li>

<li>Click <b>Edit details</b>.</li>

<li>Under <b>Tags</b>, select the current project.</li>

<li>Configure the tag:</li>

| Key | Value |
| :-- | :---- |
| **sensitivity-level** | `low` |

<li>Click <b>Save</b>.</li>

</ol>

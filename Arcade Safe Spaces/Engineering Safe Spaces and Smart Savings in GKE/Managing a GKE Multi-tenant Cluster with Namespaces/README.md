# Managing a GKE Multi-tenant Cluster with Namespaces

<h2>📋 Steps</h2>

<ol>
  <li>Open <b>Cloud Shell</b>.</li>

  <li>Set the zone provided in the lab:</li>

```bash
export ZONE=<LAB_REGION>
```

  <li>Run the following commands:</li>

```bash
curl -LO https://raw.githubusercontent.com/deep-sengupta/GCP-Labs-2026/refs/heads/master/Arcade%20Safe%20Spaces/Engineering%20Safe%20Spaces%20and%20Smart%20Savings%20in%20GKE/Managing%20a%20GKE%20Multi-tenant%20Cluster%20with%20Namespaces/GSP766.sh
sudo chmod +x GSP766.sh
./GSP766.sh
```

  <li>Open the authorization link displayed in Cloud Shell.</li>

  <li>Select your Google account and copy the generated authorization token.</li>

  <li>Paste the token back into Cloud Shell and continue.</li>

  <li>Open the <b>Data Studio Data Sources</b> link provided in <b>Task 5</b>.</li>

  <li>Click <b>Create → Resources</b> to add a new data source.</li>

  <li>Select your country, enter the company name, accept the acknowledgement, and click <b>Continue</b>.</li>

  <li>Select <b>No</b> for all email preference options and click <b>Continue</b>.</li>

  <li>Select <b>BigQuery</b> and click <b>Authorize</b>.</li>

  <li>Select <b>CUSTOM QUERY</b> from the first column.</li>

  <li>Select your <b>Project ID</b>.</li>

  <li>Paste the following query, replacing <code>[PROJECT-ID]</code> with your lab Project ID:</li>

```sql
SELECT * FROM `[PROJECT-ID].cluster_dataset.usage_metering_cost_breakdown`
```

  <li>Click <b>CONNECT</b>.</li>

</ol>

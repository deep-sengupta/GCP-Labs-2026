# Implementing Security in Knowledge Catalog

<h2>📋 Steps</h2>

<ol>
  <li>Log in to the lab using <b>Username 1</b>.</li>

  <li>Open <b>Cloud Shell</b>.</li>

  <li>Run the following commands:</li>

```bash
curl -LO https://raw.githubusercontent.com/deep-sengupta/GCP-Labs-2026/refs/heads/master/Arcade%20Simulator/Enterprise%20Governance%20and%20Data%20Mesh%20Architecture/Implementing%20Security%20in%20Knowledge%20Catalog/GSP1157.sh
sudo chmod +x GSP1157.sh
./GSP1157.sh
```

  <li>When prompted, enter your <b>Region</b> in the terminal.</li>

  <li>Open the link generated in Cloud Shell in a <b>new browser tab</b>.</li>

  <li>
    Grant the first IAM role:
    <ul>
      <li>Copy <b>Username 2</b>.</li>
      <li>Paste it into the <b>New principals</b> field.</li>
      <li>Select <b>Cloud Dataplex → Dataplex Data Reader</b>.</li>
      <li>Click <b>Save</b>.</li>
    </ul>
  </li>

  <li>
    Grant the second IAM role:
    <ul>
      <li>Click <b>Grant Access</b>.</li>
      <li>Paste <b>Username 2</b> into the <b>New principals</b> field.</li>
      <li>Select <b>Cloud Dataplex → Dataplex Data Writer</b>.</li>
      <li>Click <b>Save</b>.</li>
    </ul>
  </li>

  <li>Sign in using <b>Username 2</b>.</li>

  <li>Open the provided <b>Cloud Storage bucket</b>.</li>

  <li>Upload the <code>test.csv</code> file to the bucket.</li>

  <li>Click <b>Check my progress</b> to verify the lab completion.</li>

</ol>

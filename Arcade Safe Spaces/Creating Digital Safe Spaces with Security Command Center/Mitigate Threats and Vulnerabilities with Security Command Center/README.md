# Mitigate Threats and Vulnerabilities with Security Command Center: Challenge Lab

<h2>📋 Steps</h2>

<ol>
  <li>Open <b>Cloud Shell</b>.</li>

  <li>Authenticate with Google Cloud:</li>

```bash
gcloud auth login
```

  <li>Run the following commands:</li>

```bash
curl -LO <URL>
sudo chmod +x GSP382.sh
./GSP382.sh
```

  <li>When prompted in the terminal, type <code>y</code> to continue.</li>

  <li>Open the link generated in the Cloud Shell.</li>

  <li>
    Reserve a static external IP address:
    <ul>
      <li>Click the <b>External IPv4 address</b> dropdown.</li>
      <li>Select <b>Reserve Static External IP address</b>.</li>
      <li>Enter <code>static-ip</code> as the name.</li>
      <li>Click <b>Reserve</b>.</li>
    </ul>
  </li>

  <li>Return to the Cloud Shell and type <code>y</code> to continue.</li>

  <li>Copy the reserved external IP address.</li>

  <li>Open the next link generated in the Cloud Shell.</li>

  <li>
    Configure the application:
    <ul>
      <li>Paste the copied IP address into the <b>Starting URL</b> field.</li>
      <li>Click <b>Save</b>.</li>
    </ul>
  </li>

</ol>
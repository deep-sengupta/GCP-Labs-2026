# Create and Add Aspects to Knowledge Catalog Assets

<h2>📋 Steps</h2>

<ol>
  <li>Open <b>Cloud Shell</b>.</li>

  <li>Run the following commands:</li>

```bash
curl -LO
sudo chmod +x GSP1145.sh
./GSP1145.sh
```

  <li>Enter the required <b>Region</b> when prompted in Cloud Shell.</li>

  <li>Open <b>Data Catalog</b> and click <b>Enable</b>.</li>

  <li>Navigate to <b>Metadata Types</b> and click <b>Create</b>.</li>

  <li>
    Configure the metadata type:
    <ul>
      <li>Enter the <b>Display Name</b>.</li>
      <li>Select the <b>Location</b>.</li>
    </ul>
  </li>

  <li>
    Click <b>Add Field</b> and provide:
    <ul>
      <li>Display Name</li>
      <li>Type</li>
      <li>Enum Value</li>
    </ul>
    Then click <b>Done</b>.
  </li>

  <li>Open <b>Knowledge Catalog</b>.</li>

  <li>Search for <code>customer_details</code>.</li>

  <li>Select the following fields:</li>

```text
zip
state
last_name
country
email
latitude
first_name
city
longitude
```

  <li>Click <b>Add Aspect</b>.</li>

  <li>Select <b>Protected Data Aspect</b>.</li>

  <li>Set <b>Protected Data Flag</b> to <b>Yes</b>.</li>

  <li>Click <b>Save</b>.</li>

  <li>Click <b>Check my progress</b> to verify the lab completion.</li>

</ol>
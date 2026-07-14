# Cloud Run Functions: Qwik Start - Console

<h2>📋 Steps</h2>

<ol>
  <li>Open the <b>Google Cloud Console</b>.</li>

  <li>
    Navigate to:
    <ul>
      <li><b>☰ Navigation Menu → Cloud Run → Services</b></li>
    </ul>
  </li>

  <li>Click <b>WRITE A FUNCTION</b>.</li>

  <li>
    Configure the function with the following settings:
  </li>

| Setting | Value |
| :------ | :---- |
| **Service Name** | `gcfunction` |
| **Region** | `REGION` |
| **Authentication** | `Allow public access` |
| **Memory** | `Default` |
| **Execution Environment** | `Second generation` |
| **Maximum Instances** | `5` |

  <li>Click <b>SAVE AND REDEPLOY</b>.</li>

  <li>Wait until the deployment completes successfully (✔️).</li>

  <li>
    Test the deployed function:
    <ul>
      <li>Open the function details page.</li>
      <li>Click <b>TEST</b>.</li>
      <li>In the <b>Triggering event</b> field, enter:</li>
    </ul>

```json
{
  "message": "Hello World!"
}
```

  </li>

  <li>Copy the generated CLI test command and run it in <b>Cloud Shell</b>.</li>

  <li>Verify that the output displays:</li>

```text
Hello World!
```

</ol>
# Analyze Sentiment with Natural Language API: Challenge Lab

<h2>📋 Steps</h2>

<ol>
  <li>Create an <b>API Key</b>.</li>
  <li>Open the provided <b>Google Docs</b> link from the lab in an <b>Incognito</b> window.</li>
  <li>Paste the required text from the lab into the Google Docs document.</li>
  <li>Go to <b>VM instances</b> and open the <b>SSH</b> terminal.</li>
  <li>Create a file named <b>analyze-request.json</b> and paste the content provided in the lab.</li>

```bash
nano analyze-request.json
```

  <li>Export your API key.</li>

```bash
export API_KEY=<YOUR_API_KEY>
```

  <li>Run the following command:</li>

```bash
curl -s -H "Content-Type: application/json" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
"https://language.googleapis.com/v1/documents:analyzeSyntax" \
-d @analyze-request.json > analyze-response.txt
```

  <li>Create another file named <b>multi-nl-request.json</b> and paste the content provided in the lab.</li>

```bash
nano multi-nl-request.json
```

  <li>Run the following command:</li>

```bash
curl -s -H "Content-Type: application/json" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
"https://language.googleapis.com/v1/documents:analyzeEntities" \
-d @multi-nl-request.json > multi-response.txt
```

</ol>
# Google Cloud Storage - Bucket Lock

<h2>📋 Steps</h2>

<ol>

<li>Set the default region:</li>

```bash
gcloud config set compute/region "REGION"
```

<li>Set the bucket name to your project ID:</li>

```bash
export BUCKET=$(gcloud config get-value project)
```

<li>Create a new Cloud Storage bucket:</li>

```bash
gsutil mb "gs://$BUCKET"
```

<li>Click <b>Authorize</b> if prompted.</li>

<li>Apply a 10-second retention policy to the bucket:</li>

```bash
gsutil retention set 10s "gs://$BUCKET"
```

<li>Verify the retention policy:</li>

```bash
gsutil retention get "gs://$BUCKET"
```

<li>Upload the sample transactions file:</li>

```bash
gsutil cp gs://spls/gsp297/dummy_transactions "gs://$BUCKET/"
```

<li>View the object's retention information:</li>

```bash
gsutil ls -L "gs://$BUCKET/dummy_transactions"
```

<li>Lock the retention policy:</li>

```bash
gsutil retention lock "gs://$BUCKET/"
```

<ul>
  <li>Enter <b>Y</b> to confirm.</li>
</ul>

<li>Apply a temporary hold to the object:</li>

```bash
gsutil retention temp set "gs://$BUCKET/dummy_transactions"
```

<li>Attempt to delete the object:</li>

```bash
gsutil rm "gs://$BUCKET/dummy_transactions"
```

<li>Release the temporary hold:</li>

```bash
gsutil retention temp release "gs://$BUCKET/dummy_transactions"
```

<li>Delete the object after the retention period expires:</li>

```bash
gsutil rm "gs://$BUCKET/dummy_transactions"
```

<li>Enable the default event-based hold for the bucket:</li>

```bash
gsutil retention event-default set "gs://$BUCKET/"
```

<li>Upload the sample loan file:</li>

```bash
gsutil cp gs://spls/gsp297/dummy_loan "gs://$BUCKET/"
```

<li>Verify that the event-based hold is enabled:</li>

```bash
gsutil ls -L "gs://$BUCKET/dummy_loan"
```

<li>Release the event-based hold:</li>

```bash
gsutil retention event release "gs://$BUCKET/dummy_loan"
```

<li>Verify the retention expiration for the object:</li>

```bash
gsutil ls -L "gs://$BUCKET/dummy_loan"
```

<li>Attempt to delete the loan object:</li>

```bash
gsutil rm "gs://$BUCKET/dummy_loan"
```

</ol>
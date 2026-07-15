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

<li>Open the notebook <code>deidentify-model-response-challenge-lab.ipynb</code>.</li>

<li>Run the first code cell.</li>

<li>In the Workbench instance named <b>vertex-ai-jupyterlab</b>, enter the following values:</li>

| Property | Value |
| :------- | :---- |
| **Project ID** | `PROJECT_ID` |
| **Location** | `global` |

<li>Run the next two notebook cells.</li>

<li>Replace the existing cells with the following two code blocks and run them.</li>

### Code Block 1

```python
# Redefine original function to inspect and deidentify output with Sensitive Data Protection
import google.cloud.dlp
from typing import List

def deidentify_with_replace_infotype(
    project: str, item: str, info_types: List[str]
) -> None:
    """Uses the Data Loss Prevention API to deidentify sensitive data in a
    string by replacing it with the info type.
    """
    dlp = google.cloud.dlp_v2.DlpServiceClient()

    parent = f"projects/{project}"

    inspect_config = {
        "info_types": [{"name": info_type} for info_type in info_types]
    }

    deidentify_config = {
        "info_type_transformations": {
            "transformations": [
                {
                    "primitive_transformation": {
                        "replace_with_info_type_config": {}
                    }
                }
            ]
        }
    }

    response = dlp.deidentify_content(
        request={
            "parent": parent,
            "deidentify_config": deidentify_config,
            "inspect_config": inspect_config,
            "item": {"value": item},
        }
    )

    return_payload = response.item.value

    check_types = [
        "DOCUMENT_TYPE/R&D/SOURCE_CODE",
        "US_VEHICLE_IDENTIFICATION_NUMBER",
    ]

    inspect_config_block = {
        "info_types": [{"name": t} for t in check_types]
    }

    response_inspect = dlp.inspect_content(
        request={
            "parent": parent,
            "inspect_config": inspect_config_block,
            "item": {"value": item},
        }
    )

    if response_inspect.result.findings:
        for finding in response_inspect.result.findings:
            if finding.info_type.name == "DOCUMENT_TYPE/R&D/SOURCE_CODE":
                return_payload = "[Blocked due to category: Source Code]"
            elif finding.info_type.name == "US_VEHICLE_IDENTIFICATION_NUMBER":
                return_payload = "[Blocked due to category: US VIN]"

    print(return_payload)
```

### Code Block 2

```python
# Create prompt that generates an example response with US Vehicle Identification Number (VIN)
prompt = "Is 4Y1SL65848Z411439 an example of a US Vehicle Identification Number (VIN)?"

from google.genai import types

response_vin = client.models.generate_content(
    model=model,
    contents=prompt,
    config=types.GenerateContentConfig(
        temperature=0.0,
    ),
)

print("Original Response:")
print(response_vin.text)

print("\n--- Running DLP Block Guard ---")

deidentify_with_replace_infotype(
    project=PROJECT_ID,
    item=response_vin.text,
    info_types=["US_VEHICLE_IDENTIFICATION_NUMBER"],
)
```

</ol>

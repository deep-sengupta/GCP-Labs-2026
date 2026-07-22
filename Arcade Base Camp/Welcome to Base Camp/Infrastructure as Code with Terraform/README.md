# Infrastructure as Code with Terraform

<h2>📋 Steps</h2>

<ol>
  <li>Open <b>Cloud Shell</b>.</li>

  <li>Set the zone variable:</li>

```bash
export ZONE=
```

  <li>Run the following commands:</li>

```bash
wget -O GSP750.sh "https://raw.githubusercontent.com/deep-sengupta/GCP-Labs-2026/refs/heads/master/Arcade%20Base%20Camp/Welcome%20to%20Base%20Camp/Infrastructure%20as%20Code%20with%20Terraform/GSP750.sh"
sed -i 's/\r$//' GSP750.sh
chmod +x GSP750.sh
bash GSP750.sh
```

  <li>After the lab is completed, destroy the Terraform resources:</li>

```bash
terraform destroy
```

</ol>

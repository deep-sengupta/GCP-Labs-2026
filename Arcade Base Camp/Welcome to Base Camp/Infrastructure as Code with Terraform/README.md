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
wget -O GSP750.sh ""
sed -i 's/\r$//' GSP750.sh
chmod +x GSP750.sh
bash GSP750.sh
```

  <li>After the lab is completed, destroy the Terraform resources:</li>

```bash
terraform destroy
```

</ol>
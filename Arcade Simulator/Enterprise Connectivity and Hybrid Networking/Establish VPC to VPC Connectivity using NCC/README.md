# Establish VPC to VPC Connectivity using NCC

<h2>📁 Steps</h2>

<ol>
<li>Open <b>Cloud Shell</b>.</li>
<li>Run the following commands:</li><br>

> **Note:** Replace `PROJECT_ID`, `REGION`, `ZONE`, and `SQL_INSTANCE` with the lab-mentioned details in Code 2.

```bash
#!/bin/bash

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    echo "ERROR: Project ID not found."
    echo "Run: gcloud config set project PROJECT_ID"
    return 0 2>/dev/null || true
fi

echo
echo "======================================"
echo " GSP1317 - NCC VPC Connectivity"
echo "======================================"
echo
echo "Project: $PROJECT_ID"
echo

run() {
    timeout 60s "$@"
    local rc=$?

    if [ $rc -eq 124 ]; then
        echo "Command timed out."
    elif [ $rc -ne 0 ]; then
        echo "Command returned error code: $rc"
    fi

    return 0
}

echo "[1/8] Enabling required APIs..."

run gcloud services enable \
    networkconnectivity.googleapis.com \
    compute.googleapis.com \
    sqladmin.googleapis.com \
    dns.googleapis.com \
    --project="$PROJECT_ID"

echo "APIs ready."

echo
echo "[2/8] Detecting lab resources..."

ZONE="$(gcloud compute instances describe cloudsql-client \
    --project="$PROJECT_ID" \
    --format='value(zone)' 2>/dev/null)"

if [ -z "$ZONE" ]; then
    echo "Could not automatically determine ZONE."
    echo "Set it manually:"
    echo "export ZONE=YOUR_ZONE"
    return 0 2>/dev/null || true
fi

REGION="$(echo "$ZONE" | sed 's/-[a-z]$//')"

SQL_INSTANCE="$(gcloud sql instances list \
    --project="$PROJECT_ID" \
    --format='value(name)' 2>/dev/null | head -n 1)"

echo "Region: $REGION"
echo "Zone: $ZONE"
echo "Cloud SQL: $SQL_INSTANCE"

echo
echo "[3/8] Creating NCC hub..."

HUB="$(gcloud network-connectivity hubs describe ncc-hub \
    --project="$PROJECT_ID" \
    --format='value(name)' 2>/dev/null)"

if [ -z "$HUB" ]; then
    run gcloud network-connectivity hubs create ncc-hub \
        --project="$PROJECT_ID"
else
    echo "NCC hub already exists."
fi

echo
echo "[4/8] Creating NCC VPC spokes..."

SPOKE1="$(gcloud network-connectivity spokes describe vpc1-spoke1 \
    --global \
    --project="$PROJECT_ID" \
    --format='value(name)' 2>/dev/null)"

if [ -z "$SPOKE1" ]; then
    run gcloud network-connectivity spokes linked-vpc-network create \
        vpc1-spoke1 \
        --hub=ncc-hub \
        --vpc-network=vpc1-ncc \
        --exclude-export-ranges=10.1.2.0/24 \
        --global \
        --project="$PROJECT_ID"
else
    echo "VPC1 spoke already exists."
fi

SPOKE2="$(gcloud network-connectivity spokes describe vpc2-spoke2 \
    --global \
    --project="$PROJECT_ID" \
    --format='value(name)' 2>/dev/null)"

if [ -z "$SPOKE2" ]; then
    run gcloud network-connectivity spokes linked-vpc-network create \
        vpc2-spoke2 \
        --hub=ncc-hub \
        --vpc-network=vpc2-ncc \
        --exclude-export-ranges=10.3.3.0/24 \
        --global \
        --project="$PROJECT_ID"
else
    echo "VPC2 spoke already exists."
fi

echo
echo "NCC spokes:"
gcloud network-connectivity spokes list \
    --global \
    --project="$PROJECT_ID" \
    --format='table(name,state)' \
    2>/dev/null

echo
echo "[5/8] Configuring Private Service Connect..."

PSC_ADDRESS="$(gcloud compute addresses describe cloudsql-psc \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format='value(address)' \
    2>/dev/null)"

if [ -z "$PSC_ADDRESS" ]; then

    echo "Creating PSC address..."

    run gcloud compute addresses create cloudsql-psc \
        --project="$PROJECT_ID" \
        --region="$REGION" \
        --subnet=vpc2-ncc-subnet1

    PSC_ADDRESS="$(gcloud compute addresses describe cloudsql-psc \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(address)' \
        2>/dev/null)"

fi

echo "PSC address: $PSC_ADDRESS"

echo
echo "Getting Cloud SQL service attachment..."

SERVICE_ATTACHMENT=""

if [ -n "$SQL_INSTANCE" ]; then
    SERVICE_ATTACHMENT="$(gcloud sql instances describe "$SQL_INSTANCE" \
        --project="$PROJECT_ID" \
        --format='value(pscServiceAttachmentLink)' \
        2>/dev/null)"
fi

if [ -z "$SERVICE_ATTACHMENT" ]; then
    echo "ERROR: Cloud SQL PSC service attachment not found."
else
    echo "Service attachment found."

    PSC_ENDPOINT="$(gcloud compute forwarding-rules describe cloudsql-psc-ep \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(name)' \
        2>/dev/null)"

    if [ -z "$PSC_ENDPOINT" ]; then

        echo "Creating PSC endpoint..."

        run gcloud compute forwarding-rules create cloudsql-psc-ep \
            --address=cloudsql-psc \
            --project="$PROJECT_ID" \
            --region="$REGION" \
            --network=vpc2-ncc \
            --target-service-attachment="$SERVICE_ATTACHMENT" \
            --allow-psc-global-access

    else
        echo "PSC endpoint already exists."
    fi
fi

echo
echo "[6/8] Configuring private DNS..."

DNS_ZONE="$(gcloud dns managed-zones describe cloudsql-dns \
    --project="$PROJECT_ID" \
    --format='value(name)' \
    2>/dev/null)"

if [ -z "$DNS_ZONE" ]; then

    run gcloud dns managed-zones create cloudsql-dns \
        --project="$PROJECT_ID" \
        --description="DNS zone for Cloud SQL" \
        --dns-name="${REGION}.sql.goog." \
        --networks=vpc2-ncc \
        --visibility=private

else
    echo "DNS zone already exists."
fi

DNS_RECORD=""

if [ -n "$SQL_INSTANCE" ]; then
    DNS_RECORD="$(gcloud sql instances describe "$SQL_INSTANCE" \
        --project="$PROJECT_ID" \
        --format='value(dnsName)' \
        2>/dev/null)"
fi

echo "Cloud SQL DNS: $DNS_RECORD"

if [ -n "$DNS_RECORD" ] && [ -n "$PSC_ADDRESS" ]; then

    EXISTING_RECORD="$(gcloud dns record-sets describe "$DNS_RECORD" \
        --zone=cloudsql-dns \
        --project="$PROJECT_ID" \
        --type=A \
        --format='value(name)' \
        2>/dev/null)"

    if [ -z "$EXISTING_RECORD" ]; then

        run gcloud dns record-sets create "$DNS_RECORD" \
            --project="$PROJECT_ID" \
            --zone=cloudsql-dns \
            --type=A \
            --rrdatas="$PSC_ADDRESS"

    else
        echo "DNS record already exists."
    fi
fi

echo
echo "[7/8] Testing VPC-to-VPC connectivity..."

VM1_IP="$(gcloud compute instances describe vm1-vpc1-ncc \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --format='value(networkInterfaces[0].networkIP)' \
    2>/dev/null)"

VM2_IP="$(gcloud compute instances describe vm2-vpc2-ncc \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --format='value(networkInterfaces[0].networkIP)' \
    2>/dev/null)"

echo "vm1-vpc1-ncc: $VM1_IP"
echo "vm2-vpc2-ncc: $VM2_IP"

echo
echo "Creating connectivity test..."

TEST_NAME="ncc-vpc-test"

EXISTING_TEST="$(gcloud network-management connectivity-tests describe "$TEST_NAME" \
    --project="$PROJECT_ID" \
    --format='value(name)' \
    2>/dev/null)"

if [ -z "$EXISTING_TEST" ]; then

    run gcloud network-management connectivity-tests create "$TEST_NAME" \
        --project="$PROJECT_ID" \
        --source-instance="projects/$PROJECT_ID/zones/$ZONE/instances/vm2-vpc2-ncc" \
        --destination-ip-address="$VM1_IP" \
        --protocol=ICMP

else
    echo "Connectivity test already exists."
fi

echo
echo "Waiting briefly for connectivity test..."

sleep 10

gcloud network-management connectivity-tests describe "$TEST_NAME" \
    --project="$PROJECT_ID" \
    --format='yaml(name,reachabilityDetails.result,reachabilityDetails.overallTrace)' \
    2>/dev/null || true

echo
echo "[8/8] Testing Cloud SQL through PSC..."

if [ -n "$DNS_RECORD" ]; then

    echo
    echo "Opening one SSH session to cloudsql-client."
    echo "This is the only SSH session used by the script."
    echo

    gcloud compute ssh cloudsql-client \
        --zone="$ZONE" \
        --project="$PROJECT_ID" \
        --tunnel-through-iap \
        --quiet \
        --command="
            export PGPASSWORD=changeme

            echo 'Checking Cloud SQL DNS...'
            getent hosts '$DNS_RECORD' || true

            echo
            echo 'Testing PostgreSQL connection...'
            timeout 20s psql \
                'sslmode=disable dbname=postgres user=postgres host=$DNS_RECORD' \
                -c '\l' || true

            echo
            echo 'Creating company database...'
            timeout 20s psql \
                'sslmode=disable dbname=postgres user=postgres host=$DNS_RECORD' \
                -c 'CREATE DATABASE company;' || true

            echo
            echo 'Creating employees table...'
            timeout 20s psql \
                'sslmode=disable dbname=company user=postgres host=$DNS_RECORD' \
                -c \"CREATE TABLE IF NOT EXISTS employees (
                    id SERIAL PRIMARY KEY,
                    first VARCHAR(255) NOT NULL,
                    last VARCHAR(255) NOT NULL,
                    salary DECIMAL(10,2)
                );\" || true

            echo
            echo 'Adding employees...'
            timeout 20s psql \
                'sslmode=disable dbname=company user=postgres host=$DNS_RECORD' \
                -c \"INSERT INTO employees (first,last,salary)
                    VALUES
                    ('Max','Mustermann',5000.00),
                    ('Anna','Schmidt',7000.00),
                    ('Peter','Mayer',6000.00);\" || true

            echo
            echo 'Employee records:'
            timeout 20s psql \
                'sslmode=disable dbname=company user=postgres host=$DNS_RECORD' \
                -c 'SELECT * FROM employees;' || true
        " 2>/dev/null || true

else
    echo "Cloud SQL DNS record unavailable. Skipping SQL test."
fi

echo
echo "======================================"
echo " FINAL STATUS"
echo "======================================"

echo
echo "NCC Hub:"
gcloud network-connectivity hubs describe ncc-hub \
    --project="$PROJECT_ID" \
    --format='value(name)' \
    2>/dev/null || true

echo
echo "NCC Spokes:"
gcloud network-connectivity spokes list \
    --global \
    --project="$PROJECT_ID" \
    --format='table(name,state)' \
    2>/dev/null || true

echo
echo "PSC:"
gcloud compute forwarding-rules describe cloudsql-psc-ep \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format='table(name,IPAddress,pscConnectionStatus)' \
    2>/dev/null || true

echo
echo "DNS:"
gcloud dns record-sets list \
    --zone=cloudsql-dns \
    --project="$PROJECT_ID" \
    --format='table(name,type,rrdatas)' \
    2>/dev/null || true

echo
echo "======================================"
echo " SCRIPT FINISHED"
echo "======================================"
echo
echo "Do NOT run the cleanup commands yet."
echo "First click 'Check my progress' for each lab task."
echo
```

```bash
#!/bin/bash

PROJECT_ID="LAB"
REGION="LAB"
ZONE="LAB"
SQL_INSTANCE="LAB"

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

echo "=============================================="
echo " GSP1317 - TASK 3, 4 AND 5"
echo "=============================================="

gcloud config set project "$PROJECT_ID" >/dev/null

echo
echo "=============================================="
echo " TASK 3 - VERIFY VPC CONNECTIVITY"
echo "=============================================="

VM1_IP=$(gcloud compute instances describe vm1-vpc1-ncc \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --format="value(networkInterfaces[0].networkIP)")

VM2_IP=$(gcloud compute instances describe vm2-vpc2-ncc \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --format="value(networkInterfaces[0].networkIP)")

echo "VM1 IP: $VM1_IP"
echo "VM2 IP: $VM2_IP"

echo
echo "Starting tcpdump on vm1..."

gcloud compute ssh vm1-vpc1-ncc \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --tunnel-through-iap \
    --quiet \
    --command="sudo timeout 25 tcpdump -i any icmp -v -e -n -c 8" \
    > /tmp/ncc-tcpdump.log 2>&1 &

TCPDUMP_PID=$!

sleep 5

echo "Sending ICMP traffic from vm2 to vm1..."

gcloud compute ssh vm2-vpc2-ncc \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --tunnel-through-iap \
    --quiet \
    --command="ping -c 4 $VM1_IP"

wait "$TCPDUMP_PID" 2>/dev/null || true

echo
echo "TCPDUMP RESULT:"
cat /tmp/ncc-tcpdump.log

echo
echo "Task 3 connectivity test completed."

echo
echo "=============================================="
echo " TASK 4 - PRIVATE SERVICE CONNECT"
echo "=============================================="

echo
echo "Getting VPC2 subnet information..."

CIDR=$(gcloud compute networks subnets describe vpc2-ncc-subnet1 \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(ipCidrRange)")

echo "VPC2 subnet: $CIDR"

echo
echo "Checking existing PSC address..."

PSC_IP=$(gcloud compute addresses describe cloudsql-psc \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(address)" \
    2>/dev/null)

if [ -n "$PSC_IP" ]; then

    echo "PSC address already exists."
    echo "PSC IP: $PSC_IP"

else

    echo "Creating PSC address..."

    gcloud compute addresses create cloudsql-psc \
        --project="$PROJECT_ID" \
        --region="$REGION" \
        --subnet=vpc2-ncc-subnet1

    PSC_IP=$(gcloud compute addresses describe cloudsql-psc \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(address)")

    echo "PSC IP: $PSC_IP"

fi

echo
echo "Verifying reserved address..."

gcloud compute addresses list \
    --project="$PROJECT_ID" \
    --filter="name=cloudsql-psc" \
    --format="table(name,address,status)"

echo
echo "Getting Cloud SQL service attachment..."

SERVICE_ATTACHMENT=$(gcloud sql instances describe "$SQL_INSTANCE" \
    --project="$PROJECT_ID" \
    --format="value(pscServiceAttachmentLink)")

if [ -z "$SERVICE_ATTACHMENT" ]; then
    echo
    echo "ERROR: Cloud SQL PSC service attachment was not found."
    exit 1
fi

echo "Service attachment:"
echo "$SERVICE_ATTACHMENT"

echo
echo "Creating PSC endpoint..."

EXISTING_ENDPOINT=$(gcloud compute forwarding-rules describe cloudsql-psc-ep \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(name)" \
    2>/dev/null)

if [ -n "$EXISTING_ENDPOINT" ]; then

    echo "PSC endpoint already exists."

else

    gcloud compute forwarding-rules create cloudsql-psc-ep \
        --address=cloudsql-psc \
        --project="$PROJECT_ID" \
        --region="$REGION" \
        --network=vpc2-ncc \
        --target-service-attachment="$SERVICE_ATTACHMENT" \
        --allow-psc-global-access

fi

echo
echo "Waiting for PSC connection..."

PSC_STATUS=""

for i in 1 2 3 4 5 6 7 8 9 10; do

    PSC_STATUS=$(gcloud compute forwarding-rules describe cloudsql-psc-ep \
        --project="$PROJECT_ID" \
        --region="$REGION" \
        --format="value(pscConnectionStatus)" \
        2>/dev/null)

    echo "PSC status: $PSC_STATUS"

    if [ "$PSC_STATUS" = "ACCEPTED" ]; then
        break
    fi

    sleep 5

done

if [ "$PSC_STATUS" != "ACCEPTED" ]; then
    echo
    echo "WARNING: PSC status is $PSC_STATUS"
    echo "The lab may need additional time to accept the connection."
fi

echo
echo "=============================================="
echo " CONFIGURING PRIVATE DNS"
echo "=============================================="

EXISTING_ZONE=$(gcloud dns managed-zones describe cloudsql-dns \
    --project="$PROJECT_ID" \
    --format="value(name)" \
    2>/dev/null)

if [ -n "$EXISTING_ZONE" ]; then

    echo "cloudsql-dns already exists."

else

    gcloud dns managed-zones create cloudsql-dns \
        --project="$PROJECT_ID" \
        --description="DNS zone for the Cloud SQL instances" \
        --dns-name=us-east1.sql.goog. \
        --networks=vpc2-ncc \
        --visibility=private

fi

echo
echo "Getting Cloud SQL DNS record..."

DNS_RECORD=$(gcloud sql instances describe "$SQL_INSTANCE" \
    --project="$PROJECT_ID" \
    --format="value(dnsName)")

echo "Cloud SQL DNS:"
echo "$DNS_RECORD"

if [ -z "$DNS_RECORD" ]; then
    echo "ERROR: Cloud SQL DNS record not found."
    exit 1
fi

echo
echo "Creating DNS A record..."

EXISTING_RECORD=$(gcloud dns record-sets describe "$DNS_RECORD" \
    --project="$PROJECT_ID" \
    --zone=cloudsql-dns \
    --type=A \
    --format="value(name)" \
    2>/dev/null)

if [ -n "$EXISTING_RECORD" ]; then

    echo "DNS record already exists."

else

    gcloud dns record-sets create "$DNS_RECORD" \
        --project="$PROJECT_ID" \
        --type=A \
        --rrdatas="$PSC_IP" \
        --zone=cloudsql-dns

fi

echo
echo "PSC endpoint:"
gcloud compute forwarding-rules describe cloudsql-psc-ep \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --format="table(name,IPAddress,pscConnectionStatus)"

echo
echo "DNS record:"
gcloud dns record-sets list \
    --project="$PROJECT_ID" \
    --zone=cloudsql-dns \
    --format="table(name,type,rrdatas)"

echo
echo "=============================================="
echo " TASK 4 COMPLETE"
echo "=============================================="

echo
echo "PSC IP: $PSC_IP"
echo "PSC Status: $PSC_STATUS"
echo "DNS: $DNS_RECORD"

echo
echo "=============================================="
echo " TASK 5 - CONNECT TO CLOUD SQL"
echo "=============================================="

echo
echo "Connecting to cloudsql-client..."
echo

gcloud compute ssh cloudsql-client \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --tunnel-through-iap \
    --quiet \
    --command="
export PGPASSWORD=changeme

echo 'Testing DNS resolution...'
getent hosts '$DNS_RECORD'

echo
echo 'Testing PostgreSQL connection...'
psql 'sslmode=disable dbname=postgres user=postgres host=$DNS_RECORD' -c '\l'

echo
echo 'Creating company database...'
psql 'sslmode=disable dbname=postgres user=postgres host=$DNS_RECORD' -tc \
\"SELECT 1 FROM pg_database WHERE datname = 'company';\" | grep -q 1 || \
psql 'sslmode=disable dbname=postgres user=postgres host=$DNS_RECORD' \
-c 'CREATE DATABASE company;'

echo
echo 'Connecting to company database...'

psql 'sslmode=disable dbname=company user=postgres host=$DNS_RECORD' <<'SQL'

CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    first VARCHAR(255) NOT NULL,
    last VARCHAR(255) NOT NULL,
    salary DECIMAL (10, 2)
);

INSERT INTO employees (first, last, salary)
SELECT 'Max', 'Mustermann', 5000.00
WHERE NOT EXISTS (
    SELECT 1 FROM employees
    WHERE first='Max' AND last='Mustermann'
);

INSERT INTO employees (first, last, salary)
SELECT 'Anna', 'Schmidt', 7000.00
WHERE NOT EXISTS (
    SELECT 1 FROM employees
    WHERE first='Anna' AND last='Schmidt'
);

INSERT INTO employees (first, last, salary)
SELECT 'Peter', 'Mayer', 6000.00
WHERE NOT EXISTS (
    SELECT 1 FROM employees
    WHERE first='Peter' AND last='Mayer'
);

SELECT * FROM employees;

SQL
"

echo
echo "=============================================="
echo " TASK 5 COMPLETE"
echo "=============================================="

echo
echo "Cloud SQL DNS: $DNS_RECORD"
echo "PSC IP: $PSC_IP"
echo
echo "The employees table was created and queried."
echo
echo "=============================================="
echo " ALL REQUESTED TASKS FINISHED"
echo "=============================================="
```

</ol>
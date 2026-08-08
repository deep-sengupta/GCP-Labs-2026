# Connecting Cloud Networks with NCC: Challenge Lab

<h2>📁 Steps</h2>

<ol>
<li>Open <b>Cloud Shell</b>.</li>
<li>Run the following command:</li>

```bash
#!/bin/bash

set -euo pipefail

PROJECT_ID=$(gcloud config get-value project)
HUB_NAME=ncc-hub

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              NETWORK CONNECTIVITY CENTER                   ║"
echo "║                  NCC HUB CONFIGURATION                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

echo "▶ Detecting region from existing VPN tunnels..."
REGION=$(gcloud compute vpn-tunnels list --format="value(region)" --limit=1)

if [[ -z "$REGION" ]]; then
echo "✖ Unable to detect region from VPN tunnels."
exit 1
fi

echo "✓ Region detected: $REGION"
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NCC HUB"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if gcloud network-connectivity hubs describe "$HUB_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
echo "✓ Hub $HUB_NAME already exists, skipping creation."
else
echo "▶ Creating NCC hub $HUB_NAME..."
gcloud network-connectivity hubs create "$HUB_NAME" \
--project="$PROJECT_ID" \
--description="Global NCC Hub"
fi

echo

OFFICE1_TUNNELS=$(gcloud compute vpn-tunnels list --filter="name~'office1'" --format="value(name)")
OFFICE2_TUNNELS=$(gcloud compute vpn-tunnels list --filter="name~'office2'" --format="value(name)")

if [[ -z "$OFFICE1_TUNNELS" ]]; then
echo "✖ No Office 1 VPN tunnels found!"
exit 1
fi

if [[ -z "$OFFICE2_TUNNELS" ]]; then
echo "✖ No Office 2 VPN tunnels found!"
exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ON-PREM OFFICE 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "▶ Creating spokes for On-Prem Office 1 VPN tunnels..."
i=1
while read -r tunnel_name; do
tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
spoke_name="office-1-spoke-$i"
echo "▶ Creating spoke $spoke_name for tunnel $tunnel_name"

gcloud alpha network-connectivity spokes create "$spoke_name" \
--project="$PROJECT_ID" \
--hub="$HUB_NAME" \
--region="$REGION" \
--vpn-tunnel="$tunnel_full" \
--description="Spoke for On-Prem Office 1 tunnel $i" || echo "⚠ $spoke_name may already exist."

((i++))
done <<< "$OFFICE1_TUNNELS"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ON-PREM OFFICE 2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "▶ Creating spokes for On-Prem Office 2 VPN tunnels..."
i=1
while read -r tunnel_name; do
tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
spoke_name="office-2-spoke-$i"
echo "▶ Creating spoke $spoke_name for tunnel $tunnel_name"

gcloud alpha network-connectivity spokes create "$spoke_name" \
--project="$PROJECT_ID" \
--hub="$HUB_NAME" \
--region="$REGION" \
--vpn-tunnel="$tunnel_full" \
--description="Spoke for On-Prem Office 2 tunnel $i" || echo "⚠ $spoke_name may already exist."

((i++))
done <<< "$OFFICE2_TUNNELS"

WORKLOAD_VPC1="workload-vpc-1"
WORKLOAD_VPC2="workload-vpc-2"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  WORKLOAD VPC SPOKES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "▶ Creating workload VPC spokes..."

gcloud network-connectivity spokes linked-vpc-network create workload-1-spoke \
--project="$PROJECT_ID" \
--hub="$HUB_NAME" \
--vpc-network="$WORKLOAD_VPC1" \
--global \
--description="Spoke for Workload VPC 1" || echo "⚠ workload-1-spoke may already exist."

gcloud network-connectivity spokes linked-vpc-network create workload-2-spoke \
--project="$PROJECT_ID" \
--hub="$HUB_NAME" \
--vpc-network="$WORKLOAD_VPC2" \
--global \
--description="Spoke for Workload VPC 2" || echo "⚠ workload-2-spoke may already exist."

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HYBRID OFFICE 1 SPOKES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "▶ Creating hybrid spokes for On-Prem Office 1 VPN tunnels..."
i=1
while read -r tunnel_name; do
tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
spoke_name="hybrid-office-1-spoke-$i"
echo "▶ Creating hybrid spoke $spoke_name for tunnel $tunnel_name"

gcloud alpha network-connectivity spokes create "$spoke_name" \
--project="$PROJECT_ID" \
--hub="$HUB_NAME" \
--region="$REGION" \
--vpn-tunnel="$tunnel_full" \
--description="Hybrid spoke for On-Prem Office 1 tunnel $i" || echo "⚠ $spoke_name may already exist."

((i++))
done <<< "$OFFICE1_TUNNELS"

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    CONFIGURATION DONE                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo
```

</ol>
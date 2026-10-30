#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-week3-vgw.sh
# Purpose: Temporary AWS Virtual Private Gateway (VGW) Setup for Week 3 Comparison Demo
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# NOTE: VGW VPN Connection costs $0.05/hour! Run teardown-week3-vgw.sh immediately after demo!
# ==============================================================================

set -euo pipefail

PROJECT="Hybrid-Cloud-VPN"
COURSE="Cloud-Dot1-2026-2027"
INSTRUCTOR="HuynhXuanPhung"
OWNER="NhatNguyen"
ENV="Lab-Simulation"

REGION_CLOUD="us-east-1"
REGION_ONPREM="us-west-2"

echo "=================================================================="
echo " DEPLOYING TEMPORARY AWS VIRTUAL PRIVATE GATEWAY (VGW) FOR DEMO"
echo " ⚠️ CRITICAL COST WARNING: AWS charges $0.05/hour for VPN Connection!"
echo " Must run './infrastructure/teardown-week3-vgw.sh' immediately after!"
echo "=================================================================="

# 1. Fetch Cloud VPC and On-Prem Gateway Public Elastic IP
echo "--> [1/5] Fetching Cloud VPC and On-Prem Gateway Public IP..."
CLOUD_VPC_ID=$(aws ec2 describe-vpcs --region "$REGION_CLOUD" \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=tag:Name,Values=*cloud*" \
    --query "Vpcs[0].VpcId" --output text)

ONPREM_EIP=$(aws ec2 describe-addresses --region "$REGION_ONPREM" \
    --filters "Name=tag:Project,Values=$PROJECT" \
    --query "Addresses[0].PublicIp" --output text)

if [ -z "$CLOUD_VPC_ID" ] || [ "$CLOUD_VPC_ID" == "None" ] || [ -z "$ONPREM_EIP" ] || [ "$ONPREM_EIP" == "None" ]; then
    echo "ERROR: Could not find Cloud VPC or On-Premises Elastic IP. Ensure Week 2 infrastructure is active."
    exit 1
fi

echo "Cloud VPC ID: $CLOUD_VPC_ID"
echo "On-Prem strongSwan Elastic IP: $ONPREM_EIP"

# 2. Create Virtual Private Gateway (VGW) in us-east-1
echo "--> [2/5] Creating Virtual Private Gateway (VGW) in $REGION_CLOUD..."
VGW_ID=$(aws ec2 create-vpn-gateway \
    --type ipsec.1 \
    --region "$REGION_CLOUD" \
    --tag-specifications "ResourceType=vpn-gateway,Tags=[{Key=Name,Value=${PROJECT}-vgw-cloud},{Key=Project,Value=${PROJECT}},{Key=Owner,Value=${OWNER}},{Key=Phase,Value=Week3-VGW-Demo}]" \
    --query "VpnGateway.VpnGatewayId" --output text)

echo "Created VGW ID: $VGW_ID"

# Attach VGW to Cloud VPC
echo "Attaching VGW to Cloud VPC ($CLOUD_VPC_ID)..."
aws ec2 attach-vpn-gateway --vpn-gateway-id "$VGW_ID" --vpc-id "$CLOUD_VPC_ID" --region "$REGION_CLOUD"

# 3. Create Customer Gateway (CGW) pointing to On-Prem EIP
echo "--> [3/5] Creating Customer Gateway (CGW) pointing to $ONPREM_EIP..."
CGW_ID=$(aws ec2 create-customer-gateway \
    --type ipsec.1 \
    --public-ip "$ONPREM_EIP" \
    --bgp-asn 65000 \
    --region "$REGION_CLOUD" \
    --tag-specifications "ResourceType=customer-gateway,Tags=[{Key=Name,Value=${PROJECT}-cgw-onprem},{Key=Project,Value=${PROJECT}},{Key=Owner,Value=${OWNER}}]" \
    --query "CustomerGateway.CustomerGatewayId" --output text)

echo "Created CGW ID: $CGW_ID"

# 4. Create Site-to-Site VPN Connection
echo "--> [4/5] Creating Site-to-Site VPN Connection..."
VPN_ID=$(aws ec2 create-vpn-connection \
    --type ipsec.1 \
    --customer-gateway-id "$CGW_ID" \
    --vpn-gateway-id "$VGW_ID" \
    --options "{\"StaticRoutesOnly\":true}" \
    --region "$REGION_CLOUD" \
    --tag-specifications "ResourceType=vpn-connection,Tags=[{Key=Name,Value=${PROJECT}-vpn-vgw-demo},{Key=Project,Value=${PROJECT}},{Key=Owner,Value=${OWNER}}]" \
    --query "VpnConnection.VpnConnectionId" --output text)

echo "Created VPN Connection ID: $VPN_ID"

# Add Static Route to On-Premises Network (10.10.0.0/16)
echo "Adding static route 10.10.0.0/16 to VPN Connection..."
aws ec2 create-vpn-connection-route \
    --vpn-connection-id "$VPN_ID" \
    --destination-cidr-block 10.10.0.0/16 \
    --region "$REGION_CLOUD"

# Save Resource IDs to temporary file for easy teardown
STATE_FILE="/tmp/week3_vgw_state.env"
echo "VGW_ID=$VGW_ID" > "$STATE_FILE"
echo "CGW_ID=$CGW_ID" >> "$STATE_FILE"
echo "VPN_ID=$VPN_ID" >> "$STATE_FILE"
echo "CLOUD_VPC_ID=$CLOUD_VPC_ID" >> "$STATE_FILE"
echo "Saved state to $STATE_FILE"

# 5. Summary & Next Steps
echo "--> [5/5] VGW Provisioning Initiated!"
echo "=================================================================="
echo " AWS Virtual Private Gateway Details for Demo:"
echo " - VGW ID: $VGW_ID"
echo " - CGW ID: $CGW_ID"
echo " - VPN Connection ID: $VPN_ID"
echo " - State: creating / available (takes ~3-5 mins to become available)"
echo "------------------------------------------------------------------"
echo " Check status with:"
echo " aws ec2 describe-vpn-connections --vpn-connection-ids $VPN_ID --region $REGION_CLOUD --query 'VpnConnections[0].State'"
echo ""
echo " To inspect tunnel endpoints & pre-shared keys:"
echo " aws ec2 describe-vpn-connections --vpn-connection-ids $VPN_ID --region $REGION_CLOUD --query 'VpnConnections[0].VgwTelemetry'"
echo ""
echo " ⚠️ REMINDER: XÓA NGAY SAU KHI QUAY XONG VIDEO DEMO BẰNG LỆNH:"
echo " ./infrastructure/teardown-week3-vgw.sh"
echo "=================================================================="

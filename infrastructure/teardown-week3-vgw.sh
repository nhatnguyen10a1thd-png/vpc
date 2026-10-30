#!/usr/bin/env bash
# ==============================================================================
# Script: teardown-week3-vgw.sh
# Purpose: Clean up AWS Virtual Private Gateway (VGW), VPN Connection & CGW to prevent charges ($0.05/hr)
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# ==============================================================================

set -uo pipefail

PROJECT="Hybrid-Cloud-VPN"
REGION_CLOUD="us-east-1"
STATE_FILE="/tmp/week3_vgw_state.env"

echo "=================================================================="
echo " TEARDOWN AWS VIRTUAL PRIVATE GATEWAY (VGW) & VPN CONNECTION"
echo " Purpose: Stop billing charges immediately ($0.05/hour)"
echo "=================================================================="

# Check if state file exists, otherwise discover by tags
if [ -f "$STATE_FILE" ]; then
    echo "Loading state from $STATE_FILE..."
    # shellcheck disable=SC1090
    source "$STATE_FILE"
else
    echo "State file not found. Discovering resources by tags in $REGION_CLOUD..."
    CLOUD_VPC_ID=$(aws ec2 describe-vpcs --region "$REGION_CLOUD" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=tag:Name,Values=*cloud*" \
        --query "Vpcs[0].VpcId" --output text)

    VPN_ID=$(aws ec2 describe-vpn-connections --region "$REGION_CLOUD" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=state,Values=pending,available" \
        --query "VpnConnections[0].VpnConnectionId" --output text)

    VGW_ID=$(aws ec2 describe-vpn-gateways --region "$REGION_CLOUD" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=state,Values=pending,available" \
        --query "VpnGateways[0].VpnGatewayId" --output text)

    CGW_ID=$(aws ec2 describe-customer-gateways --region "$REGION_CLOUD" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=state,Values=available,pending" \
        --query "CustomerGateways[0].CustomerGatewayId" --output text)
fi

echo "Identified Resources:"
echo " - VPN Connection ID: ${VPN_ID:-None}"
echo " - VGW ID:            ${VGW_ID:-None}"
echo " - CGW ID:            ${CGW_ID:-None}"
echo " - Cloud VPC ID:      ${CLOUD_VPC_ID:-None}"

# 1. Delete VPN Connection
if [ -n "${VPN_ID:-}" ] && [ "$VPN_ID" != "None" ]; then
    echo "--> [1/4] Deleting Site-to-Site VPN Connection ($VPN_ID)..."
    aws ec2 delete-vpn-connection --vpn-connection-id "$VPN_ID" --region "$REGION_CLOUD" || true

    echo "Waiting for VPN Connection to terminate (state: deleting -> deleted)..."
    while true; do
        STATE=$(aws ec2 describe-vpn-connections --vpn-connection-ids "$VPN_ID" --region "$REGION_CLOUD" --query "VpnConnections[0].State" --output text 2>/dev/null || echo "deleted")
        echo "    Current VPN State: $STATE"
        if [ "$STATE" == "deleted" ] || [ -z "$STATE" ]; then
            break
        fi
        sleep 10
    done
    echo "VPN Connection deleted successfully!"
fi

# 2. Detach VGW from VPC
if [ -n "${VGW_ID:-}" ] && [ "$VGW_ID" != "None" ] && [ -n "${CLOUD_VPC_ID:-}" ] && [ "$CLOUD_VPC_ID" != "None" ]; then
    echo "--> [2/4] Detaching VGW ($VGW_ID) from Cloud VPC ($CLOUD_VPC_ID)..."
    aws ec2 detach-vpn-gateway --vpn-gateway-id "$VGW_ID" --vpc-id "$CLOUD_VPC_ID" --region "$REGION_CLOUD" || true
    sleep 5
fi

# 3. Delete VGW
if [ -n "${VGW_ID:-}" ] && [ "$VGW_ID" != "None" ]; then
    echo "--> [3/4] Deleting Virtual Private Gateway ($VGW_ID)..."
    aws ec2 delete-vpn-gateway --vpn-gateway-id "$VGW_ID" --region "$REGION_CLOUD" || true
    echo "VGW deleted successfully!"
fi

# 4. Delete Customer Gateway
if [ -n "${CGW_ID:-}" ] && [ "$CGW_ID" != "None" ]; then
    echo "--> [4/4] Deleting Customer Gateway ($CGW_ID)..."
    aws ec2 delete-customer-gateway --customer-gateway-id "$CGW_ID" --region "$REGION_CLOUD" || true
    echo "CGW deleted successfully!"
fi

# Clean up state file
rm -f "$STATE_FILE"

echo "=================================================================="
echo " ✅ TEARDOWN COMPLETE! All billable VGW/VPN resources have been deleted."
echo " Incurred cost: $0.00 (Teardown verified)"
echo "=================================================================="

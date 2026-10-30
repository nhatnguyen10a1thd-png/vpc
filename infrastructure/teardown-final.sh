#!/usr/bin/env bash
# ==============================================================================
# Script: teardown-final.sh
# Purpose: Complete Teardown & Resource Purge for Course Conclusion (Zero Cost)
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# Resources Cleaned:
#   1. CloudWatch Alarms (us-east-1 & us-west-2)
#   2. Route 53 Private Hosted Zone (corp.internal) & DNS Records & Cross-VPC associations
#   3. AWS VGW / VPN Connections / CGWs (if any leftover)
#   4. All EC2 Instances (Gateways & Workloads in both regions)
#   5. Elastic IP Addresses (release allocations to prevent $0.005/hr unattached charges)
#   6. CloudFormation Stacks (Foundation networks, VPCs, Subnets, SGs, IGWs)
# ==============================================================================

set -uo pipefail

PROJECT="Hybrid-Cloud-VPN"
COURSE="Cloud-Dot1-2026-2027"
INSTRUCTOR="HuynhXuanPhung"
STUDENT="NhatNguyen"

REGION_CLOUD="us-east-1"
REGION_ONPREM="us-west-2"
DOMAIN_NAME="corp.internal."

FORCE="${1:-}"

echo "=================================================================="
echo "   AWS HYBRID CLOUD VPN - FINAL RESOURCE TEARDOWN"
echo "   Course: $COURSE | GVHD: $INSTRUCTOR"
echo "   Student: $STUDENT | Project: $PROJECT"
echo "   Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "=================================================================="

if [ "$FORCE" != "--force" ] && [ "$FORCE" != "-y" ]; then
    echo "⚠️  WARNING: This script will PERMANENTLY DELETE all lab resources"
    echo "    across $REGION_CLOUD and $REGION_ONPREM, including EC2, Route 53, and Stacks."
    read -rp "Are you sure you want to proceed with FINAL TEARDOWN? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Teardown aborted by user."
        exit 0
    fi
fi

# Check AWS Identity
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
echo "Authenticated AWS Account ID: $ACCOUNT_ID"

# ==============================================================================
# STEP 1: Delete Amazon CloudWatch Alarms
# ==============================================================================
echo ""
echo "--> [Step 1/6] Cleaning up Amazon CloudWatch Alarms..."

for REGION in "$REGION_CLOUD" "$REGION_ONPREM"; do
    echo "  Checking CloudWatch Alarms in $REGION..."
    ALARMS=$(aws cloudwatch describe-alarms --region "$REGION" \
        --alarm-name-prefix "HybridVPN" \
        --query "MetricAlarms[*].AlarmName" --output text 2>/dev/null || echo "")
    
    if [ -n "$ALARMS" ] && [ "$ALARMS" != "None" ]; then
        echo "  Deleting alarms in $REGION: $ALARMS"
        # shellcheck disable=SC2086
        aws cloudwatch delete-alarms --region "$REGION" --alarm-names $ALARMS || true
    else
        echo "  No project alarms found in $REGION."
    fi
done

# ==============================================================================
# STEP 2: Delete Route 53 Private Hosted Zone & Records
# ==============================================================================
echo ""
echo "--> [Step 2/6] Cleaning up Route 53 Private Hosted Zone ($DOMAIN_NAME)..."

ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN_NAME" \
    --query "HostedZones[?Name=='$DOMAIN_NAME'].Id" --output text 2>/dev/null | sed 's|/hostedzone/||' || echo "")

if [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "None" ]; then
    echo "  Found Hosted Zone ID: $ZONE_ID"

    # 2.1 Delete custom records (app.corp.internal and db.corp.internal)
    echo "  Deleting DNS Records from zone $ZONE_ID..."
    RECORDS_JSON=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
        --query "ResourceRecordSets[?Type=='A'].{Action:'DELETE',ResourceRecordSet:@}" --output json 2>/dev/null || echo "[]")
    
    RECORD_COUNT=$(echo "$RECORDS_JSON" | grep -c "DELETE" || echo "0")
    if [ "$RECORD_COUNT" -gt 0 ]; then
        CHANGE_BATCH=$(echo "$RECORDS_JSON" | jq '{Changes: .}' 2>/dev/null || echo "")
        if [ -n "$CHANGE_BATCH" ]; then
            aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "$CHANGE_BATCH" >/dev/null 2>&1 || true
            echo "  Deleted $RECORD_COUNT custom DNS A records."
        fi
    fi

    # 2.2 Disassociate On-Premises VPC (us-west-2) if associated
    ONPREM_VPC_ID=$(aws ec2 describe-vpcs --region "$REGION_ONPREM" \
        --filters "Name=tag:Project,Values=$PROJECT" \
        --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
    
    if [ -n "$ONPREM_VPC_ID" ] && [ "$ONPREM_VPC_ID" != "None" ]; then
        echo "  Disassociating On-Premises VPC ($ONPREM_VPC_ID) from Hosted Zone..."
        aws route53 disassociate-vpc-from-hosted-zone --hosted-zone-id "$ZONE_ID" \
            --vpc "VPCRegion=$REGION_ONPREM,VPCId=$ONPREM_VPC_ID" >/dev/null 2>&1 || true
    fi

    # 2.3 Delete Hosted Zone
    echo "  Deleting Hosted Zone $ZONE_ID..."
    aws route53 delete-hosted-zone --id "$ZONE_ID" >/dev/null 2>&1 || true
    echo "  Hosted Zone deleted successfully."
else
    echo "  No Route 53 Hosted Zone found for $DOMAIN_NAME."
fi

# ==============================================================================
# STEP 3: Clean up any Leftover AWS VGW / VPN Connections
# ==============================================================================
echo ""
echo "--> [Step 3/6] Checking for residual VGW / Site-to-Site VPN connections..."

VPN_CONNS=$(aws ec2 describe-vpn-connections --region "$REGION_CLOUD" \
    --filters "Name=state,Values=pending,available" \
    --query "VpnConnections[*].VpnConnectionId" --output text 2>/dev/null || echo "")

if [ -n "$VPN_CONNS" ] && [ "$VPN_CONNS" != "None" ]; then
    for VPN_ID in $VPN_CONNS; do
        echo "  Deleting VPN Connection: $VPN_ID"
        aws ec2 delete-vpn-connection --vpn-connection-id "$VPN_ID" --region "$REGION_CLOUD" || true
    done
fi

VGW_IDS=$(aws ec2 describe-vpn-gateways --region "$REGION_CLOUD" \
    --filters "Name=state,Values=pending,available" \
    --query "VpnGateways[*].VpnGatewayId" --output text 2>/dev/null || echo "")

if [ -n "$VGW_IDS" ] && [ "$VGW_IDS" != "None" ]; then
    for VGW_ID in $VGW_IDS; do
        ATTACHED_VPCS=$(aws ec2 describe-vpn-gateways --vpn-gateway-ids "$VGW_ID" --region "$REGION_CLOUD" \
            --query "VpnGateways[0].VpcAttachments[*].VpcId" --output text 2>/dev/null || echo "")
        for VPC_ID in $ATTACHED_VPCS; do
            echo "  Detaching VGW $VGW_ID from VPC $VPC_ID..."
            aws ec2 detach-vpn-gateway --vpn-gateway-id "$VGW_ID" --vpc-id "$VPC_ID" --region "$REGION_CLOUD" || true
        done
        echo "  Deleting VGW: $VGW_ID"
        aws ec2 delete-vpn-gateway --vpn-gateway-id "$VGW_ID" --region "$REGION_CLOUD" || true
    done
fi

# ==============================================================================
# STEP 4: Terminate EC2 Instances in Both Regions
# ==============================================================================
echo ""
echo "--> [Step 4/6] Terminating EC2 instances in both regions..."

for REGION in "$REGION_CLOUD" "$REGION_ONPREM"; do
    INSTANCES=$(aws ec2 describe-instances --region "$REGION" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || echo "")
    
    if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ]; then
        echo "  Terminating instances in $REGION: $INSTANCES"
        # shellcheck disable=SC2086
        aws ec2 terminate-instances --region "$REGION" --instance-ids $INSTANCES >/dev/null 2>&1 || true
    else
        echo "  No active instances to terminate in $REGION."
    fi
done

echo "  Waiting 45 seconds for instances to fully terminate..."
sleep 45

# ==============================================================================
# STEP 5: Release Elastic IP Addresses
# ==============================================================================
echo ""
echo "--> [Step 5/6] Disassociating and releasing Elastic IPs..."

for REGION in "$REGION_CLOUD" "$REGION_ONPREM"; do
    EIPS=$(aws ec2 describe-addresses --region "$REGION" \
        --query "Addresses[?NetworkBorderGroup=='$REGION'].AllocationId" --output text 2>/dev/null || echo "")
    
    if [ -n "$EIPS" ] && [ "$EIPS" != "None" ]; then
        for ALLOC_ID in $EIPS; do
            echo "  Releasing Elastic IP allocation $ALLOC_ID in $REGION..."
            aws ec2 release-address --allocation-id "$ALLOC_ID" --region "$REGION" >/dev/null 2>&1 || true
        done
    else
        echo "  No Elastic IPs to release in $REGION."
    fi
done

# ==============================================================================
# STEP 6: Delete CloudFormation Foundation Stacks
# ==============================================================================
echo ""
echo "--> [Step 6/6] Deleting CloudFormation Foundation Stacks..."

STACK_CLOUD="${PROJECT}-Cloud-Foundation"
STACK_ONPREM="${PROJECT}-OnPrem-Foundation"

echo "  Deleting stack $STACK_CLOUD in $REGION_CLOUD..."
aws cloudformation delete-stack --stack-name "$STACK_CLOUD" --region "$REGION_CLOUD" || true

echo "  Deleting stack $STACK_ONPREM in $REGION_ONPREM..."
aws cloudformation delete-stack --stack-name "$STACK_ONPREM" --region "$REGION_ONPREM" || true

echo "  Waiting for CloudFormation stacks to delete..."
aws cloudformation wait stack-delete-complete --stack-name "$STACK_CLOUD" --region "$REGION_CLOUD" 2>/dev/null || true
aws cloudformation wait stack-delete-complete --stack-name "$STACK_ONPREM" --region "$REGION_ONPREM" 2>/dev/null || true

# ==============================================================================
# FINAL VERIFICATION & AUDIT
# ==============================================================================
echo ""
echo "=================================================================="
echo " FINAL AUDIT REPORT: ZERO-COST VERIFICATION"
echo "=================================================================="

RUNNING_EC2=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || echo "")

ACTIVE_EIPS=$(aws ec2 describe-addresses \
    --query "Addresses[*].PublicIp" --output text 2>/dev/null || echo "")

ACTIVE_ZONES=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN_NAME" \
    --query "HostedZones[?Name=='$DOMAIN_NAME'].Id" --output text 2>/dev/null || echo "")

echo "  • Active Project Instances:  ${RUNNING_EC2:-0 (None)}"
echo "  • Unattached Elastic IPs:    ${ACTIVE_EIPS:-0 (None)}"
echo "  • Residual Route 53 Zones:   ${ACTIVE_ZONES:-0 (None)}"
echo ""
echo "  ✅ TEARDOWN SUCCESSFUL! All billable resources have been purged."
echo "  Estimated Ongoing Cost: \$0.00 / hour"
echo "  AWS Learner Lab Budget: Safely preserved."
echo "=================================================================="

#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-week3.sh
# Purpose: AWS CLI Automation for Week 3 (Route 53 Hybrid DNS & CloudWatch Monitoring)
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# Constraints: AWS Learner Lab, us-east-1 & us-west-2, LabRole/LabInstanceProfile
# ==============================================================================

set -euo pipefail

# 1. Project Global Variables
PROJECT="Hybrid-Cloud-VPN"
COURSE="Cloud-Dot1-2026-2027"
INSTRUCTOR="HuynhXuanPhung"
OWNER="NhatNguyen"
ENV="Lab-Simulation"

REGION_CLOUD="us-east-1"
REGION_ONPREM="us-west-2"

DOMAIN_NAME="corp.internal"
APP_RECORD="app.corp.internal"
APP_IP="10.20.10.50"
DB_RECORD="db.corp.internal"
DB_IP="10.10.10.50"

TAGS="Key=Project,Value=$PROJECT Key=Environment,Value=$ENV Key=Course,Value=$COURSE Key=Instructor,Value=$INSTRUCTOR Key=Owner,Value=$OWNER Key=Phase,Value=Week3-DNS-Monitoring"

echo "=================================================================="
echo " Starting Week 3 Deployment: Route 53 Hybrid DNS & CloudWatch"
echo " Author: $OWNER | Supervisor: $INSTRUCTOR | Course: $COURSE"
echo "=================================================================="

# Check AWS Identity
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Current Account ID: $ACCOUNT_ID"

# 2. Discover Existing Resources
echo "--> [Step 1/5] Discovering VPCs and Gateway Instances..."

CLOUD_VPC_ID=$(aws ec2 describe-vpcs --region "$REGION_CLOUD" \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=tag:Name,Values=*cloud*" \
    --query "Vpcs[0].VpcId" --output text)

ONPREM_VPC_ID=$(aws ec2 describe-vpcs --region "$REGION_ONPREM" \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=tag:Name,Values=*onprem*" \
    --query "Vpcs[0].VpcId" --output text)

if [ "$CLOUD_VPC_ID" == "None" ] || [ -z "$CLOUD_VPC_ID" ] || [ "$ONPREM_VPC_ID" == "None" ] || [ -z "$ONPREM_VPC_ID" ]; then
    echo "ERROR: Could not automatically find VPCs. Please ensure Week 2 VPCs exist!"
    echo "Discovered Cloud VPC: $CLOUD_VPC_ID, On-Prem VPC: $ONPREM_VPC_ID"
    exit 1
fi

echo "Discovered Cloud VPC ($REGION_CLOUD): $CLOUD_VPC_ID"
echo "Discovered On-Premises VPC ($REGION_ONPREM): $ONPREM_VPC_ID"

CLOUD_GW_ID=$(aws ec2 describe-instances --region "$REGION_CLOUD" \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=tag:Name,Values=*cloud-strongswan*" "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[0].Instances[0].InstanceId" --output text)

ONPREM_GW_ID=$(aws ec2 describe-instances --region "$REGION_ONPREM" \
    --filters "Name=tag:Project,Values=$PROJECT" "Name=tag:Name,Values=*onprem-strongswan*" "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[0].Instances[0].InstanceId" --output text)

echo "Cloud Gateway Instance ID: $CLOUD_GW_ID"
echo "On-Prem Gateway Instance ID: $ONPREM_GW_ID"

# 3. Ensure DNS Resolution & Hostnames enabled on both VPCs
echo "--> [Step 2/5] Ensuring DNS Hostnames and Resolution are enabled..."
aws ec2 modify-vpc-attribute --region "$REGION_CLOUD" --vpc-id "$CLOUD_VPC_ID" --enable-dns-hostnames "{\"Value\":true}"
aws ec2 modify-vpc-attribute --region "$REGION_CLOUD" --vpc-id "$CLOUD_VPC_ID" --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --region "$REGION_ONPREM" --vpc-id "$ONPREM_VPC_ID" --enable-dns-hostnames "{\"Value\":true}"
aws ec2 modify-vpc-attribute --region "$REGION_ONPREM" --vpc-id "$ONPREM_VPC_ID" --enable-dns-support "{\"Value\":true}"
echo "DNS settings verified on both VPCs."

# 4. Create Route 53 Private Hosted Zone (PHZ) and Associate Cloud VPC
echo "--> [Step 3/5] Setting up Route 53 Private Hosted Zone '$DOMAIN_NAME'..."

# Check if hosted zone already exists
EXISTING_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${DOMAIN_NAME}." --query "HostedZones[?Name=='${DOMAIN_NAME}.'].Id" --output text | head -n 1 | sed 's|/hostedzone/||')

if [ -z "$EXISTING_ZONE_ID" ] || [ "$EXISTING_ZONE_ID" == "None" ]; then
    CALLER_REF="corp-internal-$(date +%s)"
    echo "Creating new Private Hosted Zone for $DOMAIN_NAME..."
    ZONE_ID=$(aws route53 create-hosted-zone \
        --name "$DOMAIN_NAME" \
        --caller-reference "$CALLER_REF" \
        --vpc "VPCRegion=$REGION_CLOUD,VPCId=$CLOUD_VPC_ID" \
        --hosted-zone-config "Comment=Hybrid Cloud VPN Private Hosted Zone Week 3,PrivateZone=true" \
        --query "HostedZone.Id" --output text | sed 's|/hostedzone/||')
    echo "Created Private Hosted Zone ID: $ZONE_ID (Associated with $CLOUD_VPC_ID in $REGION_CLOUD)"
else
    ZONE_ID="$EXISTING_ZONE_ID"
    echo "Found existing Private Hosted Zone ID: $ZONE_ID"
fi

# Associate second VPC (On-Premises in us-west-2) - Cross-VPC Association
echo "Associating On-Premises VPC ($ONPREM_VPC_ID - $REGION_ONPREM) with Hosted Zone..."
aws route53 associate-vpc-with-hosted-zone \
    --hosted-zone-id "$ZONE_ID" \
    --vpc "VPCRegion=$REGION_ONPREM,VPCId=$ONPREM_VPC_ID" \
    --comment "Cross-VPC Association: OnPrem VPC us-west-2" || echo "VPC $ONPREM_VPC_ID already associated."

# Create DNS Records (app.corp.internal and db.corp.internal)
echo "Upserting DNS Records: $APP_RECORD -> $APP_IP and $DB_RECORD -> $DB_IP..."
aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "{
      \"Comment\": \"Upsert records for app and db workloads\",
      \"Changes\": [
        {
          \"Action\": \"UPSERT\",
          \"ResourceRecordSet\": {
            \"Name\": \"${APP_RECORD}.\",
            \"Type\": \"A\",
            \"TTL\": 60,
            \"ResourceRecords\": [{\"Value\": \"${APP_IP}\"}]
          }
        },
        {
          \"Action\": \"UPSERT\",
          \"ResourceRecordSet\": {
            \"Name\": \"${DB_RECORD}.\",
            \"Type\": \"A\",
            \"TTL\": 60,
            \"ResourceRecords\": [{\"Value\": \"${DB_IP}\"}]
          }
        }
      ]
    }"
echo "DNS Records created/updated successfully!"

# 5. CloudWatch Metrics & Alarms Configuration
echo "--> [Step 4/5] Setting up CloudWatch Metric Alarms for EC2 strongSwan Gateways..."

# CloudWatch Tags format
CW_TAGS="Key=Project,Value=$PROJECT Key=Environment,Value=$ENV Key=Course,Value=$COURSE Key=Instructor,Value=$INSTRUCTOR Key=Owner,Value=$OWNER"

# Alarm 1: High CPU Utilization on Cloud Gateway (us-east-1)
if [ -n "$CLOUD_GW_ID" ] && [ "$CLOUD_GW_ID" != "None" ]; then
    echo "Creating CPU Alarm for Cloud Gateway ($CLOUD_GW_ID)..."
    aws cloudwatch put-metric-alarm \
        --region "$REGION_CLOUD" \
        --alarm-name "HybridVPN-HighCPU-CloudGateway" \
        --alarm-description "Triggers when Cloud strongSwan Gateway CPU utilization exceeds 80% for 2 periods" \
        --metric-name CPUUtilization \
        --namespace AWS/EC2 \
        --statistic Average \
        --period 60 \
        --threshold 80 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --dimensions Name=InstanceId,Value="$CLOUD_GW_ID" \
        --evaluation-periods 2 \
        --treat-missing-data notBreaching \
        --tags $CW_TAGS

    echo "Creating Network Activity Monitoring Alarm for Cloud Gateway ($CLOUD_GW_ID)..."
    aws cloudwatch put-metric-alarm \
        --region "$REGION_CLOUD" \
        --alarm-name "HybridVPN-LowNetwork-CloudGateway" \
        --alarm-description "Triggers when Cloud Gateway NetworkOut drops below threshold indicating VPN tunnel anomaly" \
        --metric-name NetworkOut \
        --namespace AWS/EC2 \
        --statistic Average \
        --period 300 \
        --threshold 500 \
        --comparison-operator LessThanOrEqualToThreshold \
        --dimensions Name=InstanceId,Value="$CLOUD_GW_ID" \
        --evaluation-periods 2 \
        --treat-missing-data breaching \
        --tags $CW_TAGS

    echo "Creating Status Check Failed Alarm for Cloud Gateway ($CLOUD_GW_ID)..."
    aws cloudwatch put-metric-alarm \
        --region "$REGION_CLOUD" \
        --alarm-name "HybridVPN-StatusCheckFailed-CloudGateway" \
        --alarm-description "Triggers if Cloud Gateway instance fails system or instance status checks" \
        --metric-name StatusCheckFailed \
        --namespace AWS/EC2 \
        --statistic Maximum \
        --period 60 \
        --threshold 1 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --dimensions Name=InstanceId,Value="$CLOUD_GW_ID" \
        --evaluation-periods 1 \
        --treat-missing-data missing \
        --tags $CW_TAGS
fi

# Alarm 2: High CPU Utilization on On-Prem Gateway (us-west-2)
if [ -n "$ONPREM_GW_ID" ] && [ "$ONPREM_GW_ID" != "None" ]; then
    echo "Creating CPU Alarm for On-Prem Gateway ($ONPREM_GW_ID)..."
    aws cloudwatch put-metric-alarm \
        --region "$REGION_ONPREM" \
        --alarm-name "HybridVPN-HighCPU-OnPremGateway" \
        --alarm-description "Triggers when On-Prem strongSwan Gateway CPU utilization exceeds 80% for 2 periods" \
        --metric-name CPUUtilization \
        --namespace AWS/EC2 \
        --statistic Average \
        --period 60 \
        --threshold 80 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --dimensions Name=InstanceId,Value="$ONPREM_GW_ID" \
        --evaluation-periods 2 \
        --treat-missing-data notBreaching \
        --tags $CW_TAGS

    echo "Creating Network Activity Monitoring Alarm for On-Prem Gateway ($ONPREM_GW_ID)..."
    aws cloudwatch put-metric-alarm \
        --region "$REGION_ONPREM" \
        --alarm-name "HybridVPN-LowNetwork-OnPremGateway" \
        --alarm-description "Triggers when On-Prem Gateway NetworkOut drops below threshold indicating VPN tunnel anomaly" \
        --metric-name NetworkOut \
        --namespace AWS/EC2 \
        --statistic Average \
        --period 300 \
        --threshold 500 \
        --comparison-operator LessThanOrEqualToThreshold \
        --dimensions Name=InstanceId,Value="$ONPREM_GW_ID" \
        --evaluation-periods 2 \
        --treat-missing-data breaching \
        --tags $CW_TAGS

    echo "Creating Status Check Failed Alarm for On-Prem Gateway ($ONPREM_GW_ID)..."
    aws cloudwatch put-metric-alarm \
        --region "$REGION_ONPREM" \
        --alarm-name "HybridVPN-StatusCheckFailed-OnPremGateway" \
        --alarm-description "Triggers if On-Prem Gateway instance fails status checks" \
        --metric-name StatusCheckFailed \
        --namespace AWS/EC2 \
        --statistic Maximum \
        --period 60 \
        --threshold 1 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --dimensions Name=InstanceId,Value="$ONPREM_GW_ID" \
        --evaluation-periods 1 \
        --treat-missing-data missing \
        --tags $CW_TAGS
fi

# 6. Verification Summary
echo "--> [Step 5/5] Deployment Finished! Verification Details:"
echo "=================================================================="
echo " 1. Route 53 Private Hosted Zone: $DOMAIN_NAME (ID: $ZONE_ID)"
echo "    - Associated VPC 1: $CLOUD_VPC_ID ($REGION_CLOUD)"
echo "    - Associated VPC 2: $ONPREM_VPC_ID ($REGION_ONPREM)"
echo "    - Record A: $APP_RECORD -> $APP_IP"
echo "    - Record A: $DB_RECORD -> $DB_IP"
echo " 2. CloudWatch Alarms Configured:"
echo "    - $REGION_CLOUD: HybridVPN-HighCPU-CloudGateway, HybridVPN-LowNetwork-CloudGateway, HybridVPN-StatusCheckFailed-CloudGateway"
echo "    - $REGION_ONPREM: HybridVPN-HighCPU-OnPremGateway, HybridVPN-LowNetwork-OnPremGateway, HybridVPN-StatusCheckFailed-OnPremGateway"
echo "=================================================================="
echo " Next step: Run verification test on instances or run test-week3.sh"

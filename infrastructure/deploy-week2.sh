#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-week2.sh
# Purpose: Complete AWS CLI Automation for Week 2 Core Implementation
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

TAGS="Key=Project,Value=$PROJECT Key=Environment,Value=$ENV Key=Course,Value=$COURSE Key=Instructor,Value=$INSTRUCTOR Key=Owner,Value=$OWNER Key=Phase,Value=Week2-CoreImplementation"

echo "=================================================================="
echo " Starting Week 2 Core Implementation Deployment"
echo " Author: $OWNER | Supervisor: $INSTRUCTOR | Course: $COURSE"
echo "=================================================================="

# Check AWS Caller Identity
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Current Account ID: $ACCOUNT_ID"

# 2. Deploy CloudFormation Stacks for both VPC Foundations
echo "--> [Step 1/6] Deploying Cloud Foundation Stack in $REGION_CLOUD..."
aws cloudformation deploy \
    --template-file infrastructure/cloudformation-vpc-foundation.yaml \
    --stack-name "${PROJECT}-Cloud-Foundation" \
    --region "$REGION_CLOUD" \
    --parameter-overrides ProjectName="$PROJECT" Environment="$ENV" Course="$COURSE" Instructor="$INSTRUCTOR" Owner="$OWNER"

echo "--> [Step 2/6] Deploying On-Premises Foundation Stack in $REGION_ONPREM..."
aws cloudformation deploy \
    --template-file infrastructure/cloudformation-onprem-foundation.yaml \
    --stack-name "${PROJECT}-OnPrem-Foundation" \
    --region "$REGION_ONPREM" \
    --parameter-overrides ProjectName="$PROJECT" Environment="$ENV" Course="$COURSE" Instructor="$INSTRUCTOR" Owner="$OWNER"

# 3. Retrieve Foundation Resource IDs
echo "--> [Step 3/6] Fetching Resource IDs from Stacks..."
CLOUD_VPC_ID=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-Cloud-Foundation" --region "$REGION_CLOUD" --query "Stacks[0].Outputs[?OutputKey=='CloudVPCId'].OutputValue" --output text)
CLOUD_VPN_SUBNET=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-Cloud-Foundation" --region "$REGION_CLOUD" --query "Stacks[0].Outputs[?OutputKey=='CloudVPNSubnetId'].OutputValue" --output text)
CLOUD_WORKLOAD_SUBNET=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-Cloud-Foundation" --region "$REGION_CLOUD" --query "Stacks[0].Outputs[?OutputKey=='CloudWorkloadSubnetId'].OutputValue" --output text)
CLOUD_GW_SG=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-Cloud-Foundation" --region "$REGION_CLOUD" --query "Stacks[0].Outputs[?OutputKey=='CloudGatewaySGId'].OutputValue" --output text)
CLOUD_WORKLOAD_SG=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-Cloud-Foundation" --region "$REGION_CLOUD" --query "Stacks[0].Outputs[?OutputKey=='CloudWorkloadSGId'].OutputValue" --output text)
CLOUD_PRIV_RTB=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-Cloud-Foundation" --region "$REGION_CLOUD" --query "Stacks[0].Outputs[?OutputKey=='CloudPrivateRouteTableId'].OutputValue" --output text)
CLOUD_PUB_RTB=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-Cloud-Foundation" --region "$REGION_CLOUD" --query "Stacks[0].Outputs[?OutputKey=='CloudPublicRouteTableId'].OutputValue" --output text)

ONPREM_VPC_ID=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-OnPrem-Foundation" --region "$REGION_ONPREM" --query "Stacks[0].Outputs[?OutputKey=='OnPremVPCId'].OutputValue" --output text)
ONPREM_VPN_SUBNET=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-OnPrem-Foundation" --region "$REGION_ONPREM" --query "Stacks[0].Outputs[?OutputKey=='OnPremVPNSubnetId'].OutputValue" --output text)
ONPREM_WORKLOAD_SUBNET=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-OnPrem-Foundation" --region "$REGION_ONPREM" --query "Stacks[0].Outputs[?OutputKey=='OnPremWorkloadSubnetId'].OutputValue" --output text)
ONPREM_GW_SG=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-OnPrem-Foundation" --region "$REGION_ONPREM" --query "Stacks[0].Outputs[?OutputKey=='OnPremGatewaySGId'].OutputValue" --output text)
ONPREM_WORKLOAD_SG=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-OnPrem-Foundation" --region "$REGION_ONPREM" --query "Stacks[0].Outputs[?OutputKey=='OnPremWorkloadSGId'].OutputValue" --output text)
ONPREM_PRIV_RTB=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-OnPrem-Foundation" --region "$REGION_ONPREM" --query "Stacks[0].Outputs[?OutputKey=='OnPremPrivateRouteTableId'].OutputValue" --output text)
ONPREM_PUB_RTB=$(aws cloudformation describe-stacks --stack-name "${PROJECT}-OnPrem-Foundation" --region "$REGION_ONPREM" --query "Stacks[0].Outputs[?OutputKey=='OnPremPublicRouteTableId'].OutputValue" --output text)

# 4. Resolve Ubuntu 22.04 LTS AMI IDs
AMI_CLOUD=$(aws ssm get-parameter --name "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id" --region "$REGION_CLOUD" --query "Parameter.Value" --output text)
AMI_ONPREM=$(aws ssm get-parameter --name "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id" --region "$REGION_ONPREM" --query "Parameter.Value" --output text)

# Key Pair Name (use 'vockey' default in Learner Lab or create one)
KEY_NAME="vockey"

echo "--> [Step 4/6] Launching EC2 strongSwan Gateway & Workload Instances..."

# Launch Cloud Gateway (10.20.1.10)
CLOUD_GW_INSTANCE=$(aws ec2 run-instances \
    --region "$REGION_CLOUD" \
    --image-id "$AMI_CLOUD" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --subnet-id "$CLOUD_VPN_SUBNET" \
    --private-ip-address 10.20.1.10 \
    --security-group-ids "$CLOUD_GW_SG" \
    --iam-instance-profile Name=LabInstanceProfile \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}-ec2-cloud-strongswan},${TAGS}]" \
    --query "Instances[0].InstanceId" --output text)

# Launch Cloud Workload (10.20.10.50)
CLOUD_WORKLOAD_INSTANCE=$(aws ec2 run-instances \
    --region "$REGION_CLOUD" \
    --image-id "$AMI_CLOUD" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --subnet-id "$CLOUD_WORKLOAD_SUBNET" \
    --private-ip-address 10.20.10.50 \
    --security-group-ids "$CLOUD_WORKLOAD_SG" \
    --iam-instance-profile Name=LabInstanceProfile \
    --user-data file://infrastructure/strongswan/setup-workload.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}-ec2-cloud-workload},${TAGS}]" \
    --query "Instances[0].InstanceId" --output text)

# Launch On-Prem Gateway (10.10.1.10)
ONPREM_GW_INSTANCE=$(aws ec2 run-instances \
    --region "$REGION_ONPREM" \
    --image-id "$AMI_ONPREM" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --subnet-id "$ONPREM_VPN_SUBNET" \
    --private-ip-address 10.10.1.10 \
    --security-group-ids "$ONPREM_GW_SG" \
    --iam-instance-profile Name=LabInstanceProfile \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}-ec2-onprem-strongswan},${TAGS}]" \
    --query "Instances[0].InstanceId" --output text)

# Launch On-Prem Workload (10.10.10.50)
ONPREM_WORKLOAD_INSTANCE=$(aws ec2 run-instances \
    --region "$REGION_ONPREM" \
    --image-id "$AMI_ONPREM" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --subnet-id "$ONPREM_WORKLOAD_SUBNET" \
    --private-ip-address 10.10.10.50 \
    --security-group-ids "$ONPREM_WORKLOAD_SG" \
    --iam-instance-profile Name=LabInstanceProfile \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}-ec2-onprem-workload},${TAGS}]" \
    --query "Instances[0].InstanceId" --output text)

echo "EC2 Instances created:"
echo " Cloud Gateway: $CLOUD_GW_INSTANCE | Cloud Workload: $CLOUD_WORKLOAD_INSTANCE"
echo " On-Prem Gateway: $ONPREM_GW_INSTANCE | On-Prem Workload: $ONPREM_WORKLOAD_INSTANCE"

# 5. Allocate and Associate Elastic IPs for Gateways
echo "--> [Step 5/6] Allocating and Associating Elastic IPs..."
CLOUD_ALLOC_ID=$(aws ec2 allocate-address --region "$REGION_CLOUD" --query "AllocationId" --output text)
CLOUD_EIP=$(aws ec2 describe-addresses --allocation-ids "$CLOUD_ALLOC_ID" --region "$REGION_CLOUD" --query "Addresses[0].PublicIp" --output text)
aws ec2 associate-address --region "$REGION_CLOUD" --instance-id "$CLOUD_GW_INSTANCE" --allocation-id "$CLOUD_ALLOC_ID"

ONPREM_ALLOC_ID=$(aws ec2 allocate-address --region "$REGION_ONPREM" --query "AllocationId" --output text)
ONPREM_EIP=$(aws ec2 describe-addresses --allocation-ids "$ONPREM_ALLOC_ID" --region "$REGION_ONPREM" --query "Addresses[0].PublicIp" --output text)
aws ec2 associate-address --region "$REGION_ONPREM" --instance-id "$ONPREM_GW_INSTANCE" --allocation-id "$ONPREM_ALLOC_ID"

echo "Public Elastic IPs:"
echo " Cloud Gateway EIP: $CLOUD_EIP"
echo " On-Prem Gateway EIP: $ONPREM_EIP"

# 6. Disable Source/Dest Check on both strongSwan Gateways
echo "--> [Step 6/6] Disabling Source/Destination Check on strongSwan Gateways..."
aws ec2 modify-instance-attribute --region "$REGION_CLOUD" --instance-id "$CLOUD_GW_INSTANCE" --no-source-dest-check
aws ec2 modify-instance-attribute --region "$REGION_ONPREM" --instance-id "$ONPREM_GW_INSTANCE" --no-source-dest-check
echo "Source/Destination Check disabled successfully!"

# 7. Add Route Table Rules for Inter-VPC Traffic (Next-hop is Gateway ENI)
echo "Fetching Gateway Network Interface IDs (ENI)..."
CLOUD_GW_ENI=$(aws ec2 describe-instances --region "$REGION_CLOUD" --instance-ids "$CLOUD_GW_INSTANCE" --query "Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId" --output text)
ONPREM_GW_ENI=$(aws ec2 describe-instances --region "$REGION_ONPREM" --instance-ids "$ONPREM_GW_INSTANCE" --query "Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId" --output text)

echo "Adding Routes targeting Gateway ENIs..."
# Cloud routes to On-Prem (10.10.0.0/16 via Cloud Gateway ENI)
aws ec2 create-route --region "$REGION_CLOUD" --route-table-id "$CLOUD_PRIV_RTB" --destination-cidr-block 10.10.0.0/16 --network-interface-id "$CLOUD_GW_ENI" || true
aws ec2 create-route --region "$REGION_CLOUD" --route-table-id "$CLOUD_PUB_RTB" --destination-cidr-block 10.10.0.0/16 --network-interface-id "$CLOUD_GW_ENI" || true

# On-Prem routes to Cloud (10.20.0.0/16 via On-Prem Gateway ENI)
aws ec2 create-route --region "$REGION_ONPREM" --route-table-id "$ONPREM_PRIV_RTB" --destination-cidr-block 10.20.0.0/16 --network-interface-id "$ONPREM_GW_ENI" || true
aws ec2 create-route --region "$REGION_ONPREM" --route-table-id "$ONPREM_PUB_RTB" --destination-cidr-block 10.20.0.0/16 --network-interface-id "$ONPREM_GW_ENI" || true

echo "=================================================================="
echo " Deployment Complete! Next steps:"
echo " 1. SSH into On-Prem Gateway ($ONPREM_EIP) and run:"
echo "    sudo ./setup-gateway.sh $ONPREM_EIP $CLOUD_EIP 10.10.0.0/16 10.20.0.0/16 onprem"
echo " 2. SSH into Cloud Gateway ($CLOUD_EIP) and run:"
echo "    sudo ./setup-gateway.sh $CLOUD_EIP $ONPREM_EIP 10.20.0.0/16 10.10.0.0/16 cloud"
echo " 3. Verify tunnel: sudo ipsec statusall"
echo " 4. Test ping from On-Prem Workload (10.10.10.50) to Cloud Workload (10.20.10.50)"
echo "=================================================================="

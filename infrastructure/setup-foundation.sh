#!/usr/bin/env bash
# ==============================================================================
# Script: setup-foundation.sh
# Purpose: Initialize Foundation Network (2 VPCs, Subnets, Routing, S3, Tags)
# Course: Cloud - Dot 1 - 2026-2027
# GVHD: Huynh Xuan Phung
# Author: Nhat Nguyen (nhatnguyen10a1thd-png)
# ==============================================================================

set -euo pipefail

# Configuration Parameters
PROJECT="Hybrid-Cloud-VPN"
COURSE="Cloud-Dot1-2026-2027"
INSTRUCTOR="HuynhXuanPhung"
OWNER="NhatNguyen"
ENV="Lab-Simulation"

REGION_CLOUD="us-east-1"
REGION_ONPREM="us-west-2"

CIDR_CLOUD="10.20.0.0/16"
CIDR_ONPREM="10.10.0.0/16"

echo "=========================================================="
echo " Starting Week 1 Foundation Initialization"
echo " Project: $PROJECT | Course: $COURSE | GVHD: $INSTRUCTOR"
echo "=========================================================="

# 1. Verify AWS CLI & IAM LabRole credentials
echo "[1/4] Verifying AWS Identity and Account..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Verified AWS Account ID: $ACCOUNT_ID"

# 2. Setup S3 Configuration Storage Bucket
BUCKET_NAME="hybrid-vpn-foundation-${ACCOUNT_ID}-${REGION_CLOUD}"
echo "[2/4] Setting up S3 Config Bucket: $BUCKET_NAME..."
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION_CLOUD"
    aws s3api put-bucket-tagging --bucket "$BUCKET_NAME" --tagging "TagSet=[{Key=Project,Value=$PROJECT},{Key=Environment,Value=$ENV},{Key=Owner,Value=$OWNER}]"
    echo "Bucket $BUCKET_NAME created successfully."
else
    echo "Bucket $BUCKET_NAME already exists."
fi

# 3. Create Cloud VPC in us-east-1 (10.20.0.0/16)
echo "[3/4] Initializing Cloud VPC ($CIDR_CLOUD in $REGION_CLOUD)..."
CLOUD_VPC_ID=$(aws ec2 create-vpc \
    --cidr-block "$CIDR_CLOUD" \
    --region "$REGION_CLOUD" \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT}-vpc-cloud},{Key=Project,Value=$PROJECT},{Key=Environment,Value=$ENV},{Key=Course,Value=$COURSE},{Key=Instructor,Value=$INSTRUCTOR},{Key=Owner,Value=$OWNER}]" \
    --query 'Vpc.VpcId' --output text)

echo "Cloud VPC Created: $CLOUD_VPC_ID"
aws ec2 modify-vpc-attribute --vpc-id "$CLOUD_VPC_ID" --enable-dns-hostnames "{\"Value\":true}" --region "$REGION_CLOUD"
aws ec2 modify-vpc-attribute --vpc-id "$CLOUD_VPC_ID" --enable-dns-support "{\"Value\":true}" --region "$REGION_CLOUD"

# 4. Create Simulated On-Premises VPC in us-west-2 (10.10.0.0/16)
echo "[4/4] Initializing On-Premises VPC ($CIDR_ONPREM in $REGION_ONPREM)..."
ONPREM_VPC_ID=$(aws ec2 create-vpc \
    --cidr-block "$CIDR_ONPREM" \
    --region "$REGION_ONPREM" \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT}-vpc-onprem},{Key=Project,Value=$PROJECT},{Key=Environment,Value=$ENV},{Key=Course,Value=$COURSE},{Key=Instructor,Value=$INSTRUCTOR},{Key=Owner,Value=$OWNER}]" \
    --query 'Vpc.VpcId' --output text)

echo "On-Premises VPC Created: $ONPREM_VPC_ID"
aws ec2 modify-vpc-attribute --vpc-id "$ONPREM_VPC_ID" --enable-dns-hostnames "{\"Value\":true}" --region "$REGION_ONPREM"
aws ec2 modify-vpc-attribute --vpc-id "$ONPREM_VPC_ID" --enable-dns-support "{\"Value\":true}" --region "$REGION_ONPREM"

echo "=========================================================="
echo " Foundation Setup Completed Successfully!"
echo " Cloud VPC: $CLOUD_VPC_ID ($REGION_CLOUD)"
echo " On-Premises VPC: $ONPREM_VPC_ID ($REGION_ONPREM)"
echo " S3 Storage: s3://$BUCKET_NAME"
echo "=========================================================="

#!/usr/bin/env bash
# ==============================================================================
# Script: teardown-week2.sh
# Purpose: Safely stop or delete resources after lab session to avoid AWS costs
# Course: Cloud - Dot 1 - 2026-2027 | GVHD: Huynh Xuan Phung | Student: Nhat Nguyen
# ==============================================================================

set -euo pipefail

PROJECT="Hybrid-Cloud-VPN"
REGION_CLOUD="us-east-1"
REGION_ONPREM="us-west-2"

echo "=================================================================="
echo " TEARDOWN & COST SAVING SCRIPT (AWS Learner Lab)"
echo " Project: $PROJECT"
echo "=================================================================="

ACTION="${1:-stop}" # options: stop | terminate

if [ "$ACTION" == "stop" ]; then
    echo "--> Stopping all EC2 instances to save compute costs..."
    
    # Find and stop Cloud instances
    CLOUD_INSTANCES=$(aws ec2 describe-instances --region "$REGION_CLOUD" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].InstanceId" --output text)
    if [ -n "$CLOUD_INSTANCES" ]; then
        echo "Stopping Cloud instances: $CLOUD_INSTANCES"
        aws ec2 stop-instances --region "$REGION_CLOUD" --instance-ids $CLOUD_INSTANCES
    fi

    # Find and stop On-Prem instances
    ONPREM_INSTANCES=$(aws ec2 describe-instances --region "$REGION_ONPREM" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].InstanceId" --output text)
    if [ -n "$ONPREM_INSTANCES" ]; then
        echo "Stopping On-Prem instances: $ONPREM_INSTANCES"
        aws ec2 stop-instances --region "$REGION_ONPREM" --instance-ids $ONPREM_INSTANCES
    fi
    echo "All instances stopped successfully. You can restart them next session."

elif [ "$ACTION" == "terminate" ]; then
    echo "--> Terminating EC2 instances and deleting CloudFormation stacks..."

    # Terminate Cloud instances
    CLOUD_INSTANCES=$(aws ec2 describe-instances --region "$REGION_CLOUD" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=running,stopped" \
        --query "Reservations[*].Instances[*].InstanceId" --output text)
    if [ -n "$CLOUD_INSTANCES" ]; then
        echo "Terminating Cloud instances: $CLOUD_INSTANCES"
        aws ec2 terminate-instances --region "$REGION_CLOUD" --instance-ids $CLOUD_INSTANCES
    fi

    # Terminate On-Prem instances
    ONPREM_INSTANCES=$(aws ec2 describe-instances --region "$REGION_ONPREM" \
        --filters "Name=tag:Project,Values=$PROJECT" "Name=instance-state-name,Values=running,stopped" \
        --query "Reservations[*].Instances[*].InstanceId" --output text)
    if [ -n "$ONPREM_INSTANCES" ]; then
        echo "Terminating On-Prem instances: $ONPREM_INSTANCES"
        aws ec2 terminate-instances --region "$REGION_ONPREM" --instance-ids $ONPREM_INSTANCES
    fi

    echo "Waiting 60 seconds for instance termination before deleting stacks..."
    sleep 60

    # Delete Stacks
    echo "Deleting Cloud Foundation Stack..."
    aws cloudformation delete-stack --stack-name "${PROJECT}-Cloud-Foundation" --region "$REGION_CLOUD"

    echo "Deleting On-Premises Foundation Stack..."
    aws cloudformation delete-stack --stack-name "${PROJECT}-OnPrem-Foundation" --region "$REGION_ONPREM"

    echo "All Week 2 lab resources terminated."
else
    echo "Invalid option. Use: ./teardown-week2.sh stop | terminate"
fi

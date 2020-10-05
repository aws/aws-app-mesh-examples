#!/usr/bin/env bash

# Load environment variables
source ~/.bash_profile

# Get the AWS Lambda role ARN
STATE_MACHINE_ROLE_ARN=$(aws cloudformation describe-stacks --region $AWS_REGION --stack-name $SHARED_STACK_NAME \
| jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "EKSAccessRole") | .OutputValue')

# Add the role to Kubernetes RBAC
eksctl create iamidentitymapping --region $AWS_REGION --cluster $EKS_CLUSTER_NAME --arn $STATE_MACHINE_ROLE_ARN \
--group system:masters --username eks_canary_stepfunctions
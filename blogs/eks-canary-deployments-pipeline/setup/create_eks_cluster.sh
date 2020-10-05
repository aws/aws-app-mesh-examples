#!/usr/bin/env bash

# Create EKS cluster
eksctl create cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION \
--managed --appmesh-access \
--alb-ingress-access --full-ecr-access

# Export cluster ARN (this variable will be used later)
export EKS_CLUSTER_ARN=$(aws eks describe-cluster --region $AWS_REGION --name $EKS_CLUSTER_NAME | jq -r '.cluster.arn')
echo "export EKS_CLUSTER_ARN=${EKS_CLUSTER_ARN}" | tee -a ~/.bash_profile

# Export node group role name (this variable will be used later)
export STACK_NAME=$(eksctl get nodegroup --region $AWS_REGION --cluster $EKS_CLUSTER_NAME -o json | jq -r '.[].StackName')
export EKS_ROLE_NAME=$(aws cloudformation describe-stack-resources --region $AWS_REGION --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.ResourceType=="AWS::IAM::Role") | .PhysicalResourceId')
echo "export EKS_ROLE_NAME=${EKS_ROLE_NAME}" | tee -a ~/.bash_profile
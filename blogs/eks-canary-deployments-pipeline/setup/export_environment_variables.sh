#!/usr/bin/env bash

# Default variables that were used on the blog post (you can change them to fit your needs)
AWS_REGION=us-west-2
EKS_CLUSTER_NAME=blogpost
SHARED_STACK_NAME=eks-deployment-stepfunctions
BUILD_COMPUTE_TYPE=BUILD_GENERAL1_SMALL
USE_SAMPLE_MICROSERVICES='True'

# Add environment variables to bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
echo "export EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME}" | tee -a ~/.bash_profile
echo "export SHARED_STACK_NAME=${SHARED_STACK_NAME}" | tee -a ~/.bash_profile
echo "export BUILD_COMPUTE_TYPE=${BUILD_COMPUTE_TYPE}" | tee -a ~/.bash_profile
echo "export USE_SAMPLE_MICROSERVICES=${USE_SAMPLE_MICROSERVICES}" | tee -a ~/.bash_profile
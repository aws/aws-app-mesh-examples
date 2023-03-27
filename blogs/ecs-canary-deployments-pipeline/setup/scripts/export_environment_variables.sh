#!/usr/bin/env bash
set -e
# Default variables that were used on the blog post (you can change them to fit your needs)
AWS_REGION=us-west-2
ENVIRONMENT_NAME=ecs-blogpost
NAMESPACE=yelb.local
ENVOY_IMAGE=public.ecr.aws/appmesh/aws-appmesh-envoy:v1.25.1.0-prod
SHARED_STACK_NAME=${ENVIRONMENT_NAME}-deployment-stepfunctions
BUILD_COMPUTE_TYPE=BUILD_GENERAL1_SMALL
USE_SAMPLE_MICROSERVICES='True'

# Add environment variables to bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
echo "export ENVIRONMENT_NAME=${ENVIRONMENT_NAME}" | tee -a ~/.bash_profile
echo "export NAMESPACE=${NAMESPACE}" | tee -a ~/.bash_profile
echo "export ENVOY_IMAGE=${ENVOY_IMAGE}" | tee -a ~/.bash_profile
echo "export SHARED_STACK_NAME=${SHARED_STACK_NAME}" | tee -a ~/.bash_profile
echo "export BUILD_COMPUTE_TYPE=${BUILD_COMPUTE_TYPE}" | tee -a ~/.bash_profile
echo "export USE_SAMPLE_MICROSERVICES=${USE_SAMPLE_MICROSERVICES}" | tee -a ~/.bash_profile

#!/usr/bin/env bash

# set this to the profile for the target AWS Account
export AWS_PROFILE=xxx
# set this to the AccountId for the target AWS Account
export AWS_ACCOUNT_ID=12345678
# we default to eu-west-2 (London)
export AWS_DEFAULT_REGION=eu-west-2

echo 'Creating colorteller ECR Repository'
aws ecr create-repository --repository-name colorteller --image-tag-mutability IMMUTABLE

echo 'Creating gateway ECR Repository'
aws ecr create-repository --repository-name gateway --image-tag-mutability IMMUTABLE

# edit this script before running scripts to create ECR Repos
echo 'Building colorteller docker image & pushing to ECR Repository'
cd apps/colorapp/src/colorteller/
./deploy.sh
cd -

echo 'Building gateway docker image & pushing to ECR Repository'
cd apps/colorapp/src/gateway
./deploy.sh
cd -


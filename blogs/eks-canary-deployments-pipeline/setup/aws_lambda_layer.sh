#!/usr/bin/env bash

# AppID for the AWS Lambda Layer that has kubectl, awscli, helm, and jq
APP_ID='arn:aws:serverlessrepo:us-east-1:903779448426:applications/lambda-layer-kubectl'

# Create the AWS CloudFormation template
TEMPLATE_URL=$(aws --region $AWS_REGION serverlessrepo \
create-cloud-formation-template --application-id  ${APP_ID} \
| jq -r '.TemplateUrl')

# Deploy the AWS CloudFormation template
aws --region $AWS_REGION cloudformation create-stack \
--template-url $TEMPLATE_URL --stack-name "kubectl-lambda-layer" \
--capabilities CAPABILITY_AUTO_EXPAND \
--parameters ParameterKey=LayerName,ParameterValue=lambda-layer-kubectl

echo -n "Creating the AWS CloudFormation stack"
while [ "$(aws cloudformation describe-stacks --stack-name kubectl-lambda-layer --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_IN_PROGRESS" ]; do
  echo -n '.'
  sleep 10
done
echo -e "\n$(aws cloudformation describe-stacks --stack-name kubectl-lambda-layer --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')"

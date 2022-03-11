#!/usr/bin/env bash

set -e
# Load environment variables
source ~/.bash_profile

# Get the base directory path that will be used to zip the resources before uploading to S3
base_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

#Checking for jq utility.
if ! command -v jq >/dev/null 2>&1; then
 sudo yum install jq -y 
fi

# Zip the microservice resources
echo "Starting the zipping activity of the microservices code"
cd $base_path/../../microservices/yelb-ui && zip -r yelb-ui.zip ./* > /dev/null
cd $base_path/../../microservices/yelb-db && zip -r yelb-db.zip ./* > /dev/null
cd $base_path/../../microservices/yelb-appserver && zip -r yelb-appserver.zip ./* > /dev/null
cd $base_path/../../microservices/yelb-redisserver && zip -r yelb-redisserver.zip ./* > /dev/null
echo "Successfully completed the zipping activity of the microservices code"

# Zip the lambda function resources
echo "Starting the zipping activity of the lambda code"
cd $base_path/../../shared_stack/lambda_functions/check_deployment_version && zip -r function.zip ./* > /dev/null
cd $base_path/../../shared_stack/lambda_functions/deploy_canary_infrastructure && zip -r function.zip ./* > /dev/null
cd $base_path/../../shared_stack/lambda_functions/gather_healthcheck_status && zip -r function.zip ./* > /dev/null
cd $base_path/../../shared_stack/lambda_functions/remove_previous_canary_components && zip -r function.zip ./* > /dev/null
cd $base_path/../../shared_stack/lambda_functions/rollbackto_previous_canary && zip -r function.zip ./* > /dev/null
cd $base_path/../../shared_stack/lambda_functions/start_canary && zip -r function.zip ./* > /dev/null
cd $base_path/../../shared_stack/lambda_functions/update_deployment_version && zip -r function.zip ./* > /dev/null
echo "Successfully completed the zipping activity of the lambda code"

# Move back to the base directory
cd $base_path/../../

# Create a new S3 bucket with a random name suffix because S3 bucket names are unique
RANDOM_STRING=$(LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 10 ; echo)
S3_BUCKET_NAME=$(aws s3 mb s3://ecs-canary-blogpost-cloudformation-files-$RANDOM_STRING --region $AWS_REGION | cut -d' ' -f2)
echo "export S3_BUCKET_NAME=${S3_BUCKET_NAME}" | tee -a ~/.bash_profile

# Upload the resources to the bucket created
aws s3 cp ./ s3://$S3_BUCKET_NAME --recursive --exclude "^\." --region $AWS_REGION > /dev/null

# Deploy AWS CloudFormation Stack
aws cloudformation create-stack --stack-name $SHARED_STACK_NAME \
--template-url "https://$S3_BUCKET_NAME.s3.amazonaws.com/shared_stack/stepfunctions_cloudformation.yml" \
--parameters ParameterKey=SourceCodeBucket,ParameterValue="$S3_BUCKET_NAME" ParameterKey=EnvironmentName,ParameterValue="${ENVIRONMENT_NAME}" \
--capabilities CAPABILITY_IAM \
--region $AWS_REGION

# aws cloudformation wait stack-create-complete --stack-name $SHARED_STACK_NAME <Until the bug gets fixed, use the below workaround>
echo -n "Creating the AWS CloudFormation stack"
while [ "$(aws cloudformation describe-stacks --stack-name $SHARED_STACK_NAME --region $AWS_REGION --output json | jq -r '.Stacks[0].StackStatus')" == "CREATE_IN_PROGRESS" ]; do
  echo -n '.'
  sleep 10
done
echo -e "\n$(aws cloudformation describe-stacks --stack-name $SHARED_STACK_NAME --region $AWS_REGION --output json | jq -r '.Stacks[0].StackStatus')"

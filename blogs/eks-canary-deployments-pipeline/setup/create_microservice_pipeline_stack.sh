#!/usr/bin/env bash

# Load environment variables
source ~/.bash_profile

# Database
aws cloudformation create-stack --stack-name eks-pipeline-yelb-db \
--template-url "https://$S3_BUCKET_NAME.s3.amazonaws.com/pipeline_stack/pipeline_cloudformation.yml" \
--parameters ParameterKey=MicroserviceName,ParameterValue="yelb-db" \
ParameterKey=SharedStackName,ParameterValue="$SHARED_STACK_NAME" \
ParameterKey=BuildComputeType,ParameterValue="$BUILD_COMPUTE_TYPE" \
ParameterKey=SourceCodeBucket,ParameterValue="$S3_BUCKET_NAME" \
ParameterKey=SampleMicroservices,ParameterValue="$USE_SAMPLE_MICROSERVICES" \
--capabilities CAPABILITY_IAM \
--region $AWS_REGION

# Redis
aws cloudformation create-stack --stack-name eks-pipeline-yelb-redis \
--template-url "https://$S3_BUCKET_NAME.s3.amazonaws.com/pipeline_stack/pipeline_cloudformation.yml" \
--parameters ParameterKey=MicroserviceName,ParameterValue="redis-server" \
ParameterKey=SharedStackName,ParameterValue="$SHARED_STACK_NAME" \
ParameterKey=BuildComputeType,ParameterValue="$BUILD_COMPUTE_TYPE" \
ParameterKey=SourceCodeBucket,ParameterValue="$S3_BUCKET_NAME" \
ParameterKey=SampleMicroservices,ParameterValue="$USE_SAMPLE_MICROSERVICES" \
--capabilities CAPABILITY_IAM \
--region $AWS_REGION

# Application Server
aws cloudformation create-stack --stack-name eks-pipeline-yelb-appserver \
--template-url "https://$S3_BUCKET_NAME.s3.amazonaws.com/pipeline_stack/pipeline_cloudformation.yml" \
--parameters ParameterKey=MicroserviceName,ParameterValue="yelb-appserver" \
ParameterKey=SharedStackName,ParameterValue="$SHARED_STACK_NAME" \
ParameterKey=BuildComputeType,ParameterValue="$BUILD_COMPUTE_TYPE" \
ParameterKey=SourceCodeBucket,ParameterValue="$S3_BUCKET_NAME" \
ParameterKey=SampleMicroservices,ParameterValue="$USE_SAMPLE_MICROSERVICES" \
--capabilities CAPABILITY_IAM \
--region $AWS_REGION

# User Interface
aws cloudformation create-stack --stack-name eks-pipeline-yelb-ui \
--template-url "https://$S3_BUCKET_NAME.s3.amazonaws.com/pipeline_stack/pipeline_cloudformation.yml" \
--parameters ParameterKey=MicroserviceName,ParameterValue="yelb-ui" \
ParameterKey=SharedStackName,ParameterValue="$SHARED_STACK_NAME" \
ParameterKey=BuildComputeType,ParameterValue="$BUILD_COMPUTE_TYPE" \
ParameterKey=SourceCodeBucket,ParameterValue="$S3_BUCKET_NAME" \
ParameterKey=SampleMicroservices,ParameterValue="$USE_SAMPLE_MICROSERVICES" \
--capabilities CAPABILITY_IAM \
--region $AWS_REGION


echo -n "Creating the AWS CloudFormation stacks"
while [ "$(aws cloudformation describe-stacks --stack-name eks-pipeline-yelb-db --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_IN_PROGRESS" ] || \
[ "$(aws cloudformation describe-stacks --stack-name eks-pipeline-yelb-redis --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_IN_PROGRESS" ] || \
[ "$(aws cloudformation describe-stacks --stack-name eks-pipeline-yelb-appserver --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_IN_PROGRESS" ] || \
[ "$(aws cloudformation describe-stacks --stack-name eks-pipeline-yelb-ui --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_IN_PROGRESS" ] ; do
  echo -n '.'
  sleep 10
done

if [ "$(aws cloudformation describe-stacks --stack-name eks-pipeline-yelb-db --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_COMPLETE" ] && \
[ "$(aws cloudformation describe-stacks --stack-name eks-pipeline-yelb-redis --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_COMPLETE" ] && \
[ "$(aws cloudformation describe-stacks --stack-name eks-pipeline-yelb-appserver --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_COMPLETE" ] && \
[ "$(aws cloudformation describe-stacks --stack-name eks-pipeline-yelb-ui --region $AWS_REGION | jq -r '.Stacks[0].StackStatus')" == "CREATE_COMPLETE" ] ; then
    echo -e "\nAll four stacks created successfully!"
else
    echo -e "\nAn error occurred while creating the stacks! Don't move forward before fixing it!"
fi



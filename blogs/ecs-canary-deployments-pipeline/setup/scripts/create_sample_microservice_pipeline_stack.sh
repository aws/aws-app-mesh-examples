#!/usr/bin/env bash

set -e

# Load environment variables
source ~/.bash_profile

sample_microservices=(
    "yelb-db:5432:tcp"
    "yelb-redisserver:6379:tcp"
    "yelb-appserver:4567:http"
    "yelb-ui:80:http"
)

for item in "${sample_microservices[@]}"; do
    MICROSERVICE=$(echo $item | awk -F ':' '{print $1}')
    PORT=$(echo $item | awk -F ':' '{print $2}')
    PROTOCOL=$(echo $item | awk -F ':' '{print $3}')
    echo "Deploying ${MICROSERVICE}"
    aws cloudformation create-stack --stack-name ${ENVIRONMENT_NAME}-pipeline-${MICROSERVICE} \
    --template-url "https://$S3_BUCKET_NAME.s3.amazonaws.com/pipeline_stack/pipeline_cloudformation.yml" \
    --parameters ParameterKey=MicroserviceName,ParameterValue=${MICROSERVICE} \
    ParameterKey=SharedStackName,ParameterValue="$SHARED_STACK_NAME" \
    ParameterKey=EnvironmentName,ParameterValue="$ENVIRONMENT_NAME" \
    ParameterKey=SourceCodeBucket,ParameterValue="$S3_BUCKET_NAME" \
    ParameterKey=SampleMicroservices,ParameterValue="$USE_SAMPLE_MICROSERVICES" \
    ParameterKey=Port,ParameterValue="$PORT" \
    ParameterKey=Protocol,ParameterValue="$PROTOCOL" \
    --capabilities CAPABILITY_IAM \
    --region $AWS_REGION
done

for item in "${sample_microservices[@]}"; do
    microservice="${item%%:*}"
    while [ "$(aws cloudformation describe-stacks --stack-name ${ENVIRONMENT_NAME}-pipeline-${MICROSERVICE} --region $AWS_REGION --output json | jq -r '.Stacks[0].StackStatus')" == "CREATE_IN_PROGRESS" ] ; do
        echo -n '.'
        sleep 10
    done
    if [ "$(aws cloudformation describe-stacks --stack-name ${ENVIRONMENT_NAME}-pipeline-${MICROSERVICE} --region $AWS_REGION --output json | jq -r '.Stacks[0].StackStatus')" != "CREATE_COMPLETE" ] ; then
        echo -e "\nAn error occurred while creating the stack ${MICROSERVICE}! Don't move forward before fixing it!"
        exit 1
    fi
done
echo -e "\nAll CloudFormation stacks created successfully!"

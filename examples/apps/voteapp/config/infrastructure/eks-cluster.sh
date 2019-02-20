#!/bin/bash

set -ex 

ACTION=${1:-"create-stack"}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile ${AWS_PROFILE} --region ${AWS_REGION} \
    cloudformation ${ACTION} \
    --stack-name ${ENVIRONMENT_NAME}-eks-cluster \
    --capabilities CAPABILITY_IAM \
    --template-body file://${DIR}/eks-cluster.yaml  \
    --parameters \
    ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
    ParameterKey=NodeImageId,ParameterValue="ami-0f54a2f7d2e9c88b3" \
    ParameterKey=KeyName,ParameterValue=${KEY_PAIR_NAME}


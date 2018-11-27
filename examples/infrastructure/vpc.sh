#!/bin/bash

set -ex

ACTION=${1:-"create-stack"}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile ${AWS_PROFILE} --region ${AWS_REGION} \
    cloudformation ${ACTION} \
    --stack-name ${ENVIRONMENT_NAME}-vpc \
    --capabilities CAPABILITY_IAM \
    --template-body file://${DIR}/vpc.yaml \
    --parameters \
    ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME}

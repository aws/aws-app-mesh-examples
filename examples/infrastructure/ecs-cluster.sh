#!/bin/bash

set -ex 

ACTION=${1:-"create-stack"}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile ${AWS_PROFILE} --region ${AWS_REGION} \
    cloudformation ${ACTION} \
    --stack-name ${ENVIRONMENT_NAME}-ecs-cluster \
    --capabilities CAPABILITY_IAM \
    --template-body file://${DIR}/ecs-cluster.yaml  \
    --parameters \
    ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
    ParameterKey=KeyName,ParameterValue=${KEY_PAIR_NAME} \
    ParameterKey=ECSServicesDomain,ParameterValue=${SERVICES_DOMAIN} \
    ParameterKey=ClusterSize,ParameterValue=${CLUSTER_SIZE:-5} 

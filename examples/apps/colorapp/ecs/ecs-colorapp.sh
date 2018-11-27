#!/bin/bash

set -ex 

ACTION=${1:-"create-stack"}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile ${AWS_PROFILE} --region ${AWS_REGION} \
    cloudformation ${ACTION} \
    --stack-name ${ENVIRONMENT_NAME}-ecs-colorapp \
    --capabilities CAPABILITY_IAM \
    --template-body file://${DIR}/ecs-colorapp.yaml  \
    --parameters \
    ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
    ParameterKey=EnvoyImage,ParameterValue=${ENVOY_IMAGE} \
    ParameterKey=AppMeshXdsEndpoint,ParameterValue=${APPMESH_XDS_ENDPOINT:-""} \
    ParameterKey=ECSServicesDomain,ParameterValue=${SERVICES_DOMAIN} \
    ParameterKey=AppMeshMeshName,ParameterValue="${MESH_NAME}"

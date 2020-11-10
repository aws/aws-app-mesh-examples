#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-ecs-service" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/ecs-service.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    ECSServicesDomain="${SERVICES_DOMAIN}" \
    AppMeshMeshName="${MESH_NAME}" \
    EnvoyImage="${ENVOY_IMAGE}" \
    ColorTellerImageName="${COLOR_TELLER_IMAGE_NAME}" \
    WrkToolImageName="${WRK_TOOL_IMAGE_NAME}"

print_bastion() {
    echo "Bastion endpoint:"
    ip=$(aws cloudformation describe-stacks \
        --stack-name="${ENVIRONMENT_NAME}-ecs-cluster" \
        --query="Stacks[0].Outputs[?OutputKey=='BastionIP'].OutputValue" \
        --output=text)
    echo "${ip}"
}

print_endpoint() {
    echo "ColorApp Endpoint:"
    prefix=$(aws cloudformation describe-stacks \
        --stack-name="${ENVIRONMENT_NAME}-ecs-service" \
        --query="Stacks[0].Outputs[?OutputKey=='ColorAppEndpoint'].OutputValue" \
        --output=text)
    echo "${prefix}"
}

print_bastion
print_endpoint

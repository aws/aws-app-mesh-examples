#!/bin/bash

set -ex 

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-ecs-colorapp" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/ecs-colorapp.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    EnvoyImage="${ENVOY_IMAGE}" \
    AppMeshXdsEndpoint="${APPMESH_XDS_ENDPOINT}" \
    ECSServicesDomain="${SERVICES_DOMAIN}" \
    AppMeshMeshName="${MESH_NAME}" \
    ColorGatewayImage="${COLOR_GATEWAY_IMAGE}" \
    ColorTellerImage="${COLOR_TELLER_IMAGE}"

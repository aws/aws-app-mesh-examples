#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
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
    ColorAppEnvoyImageName="${COLOR_APP_ENVOY_IMAGE_NAME}"


#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-deploy" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/deploy.yaml" \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}"\
    DomainName="${SERVICES_DOMAIN}" \
    ECSServicesDomain="${SERVICES_DOMAIN}" \
    AppMeshMeshName="${MESH_NAME}" \
    TlsState=$1 \
    EnvoyImageName="${ENVOY_IMAGE_NAME}" \
    ColorTellerImageName="${COLOR_TELLER_IMAGE_NAME}" 
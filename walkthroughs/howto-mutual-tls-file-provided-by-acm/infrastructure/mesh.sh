#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-mesh" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
    ServiceDomain="${SERVICES_DOMAIN}" \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    MeshName="${MESH_NAME}" \
    TlsState=$1 \
    --template-file "${DIR}/mesh.yaml"
#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Create colorteller task definition
source ${DIR}/fargate-colorteller-task-def.sh

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-fargate-colorteller" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/fargate-colorteller.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    ECSServicesDomain="${SERVICES_DOMAIN}" \
    AppMeshMeshName="${MESH_NAME}" \
    ColorTellerGreenTaskDefinition="${colorteller_green_task_def_arn}"

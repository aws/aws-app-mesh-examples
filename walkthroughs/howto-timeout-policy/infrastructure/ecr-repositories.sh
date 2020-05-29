#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-ecr-repositories" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/ecr-repositories.yaml" \
    --parameter-overrides \
    GatewayImageName="${COLOR_GATEWAY_IMAGE_NAME}" \
    ColorTellerImageName="${COLOR_TELLER_IMAGE_NAME}"

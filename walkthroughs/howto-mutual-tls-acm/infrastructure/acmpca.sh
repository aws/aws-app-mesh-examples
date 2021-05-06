#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-acm-cfn-stack" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
    DomainName="${SERVICES_DOMAIN}" \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    --template-file "${DIR}/acmpca.yaml"

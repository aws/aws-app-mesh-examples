#!/bin/bash

set -e

source ~/.bash_profile

base_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --region "${AWS_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-vpc" \
    --capabilities CAPABILITY_IAM \
    --template-file "${base_path}/../templates/vpc.yaml" \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}"

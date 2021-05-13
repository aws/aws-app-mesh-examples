#!/bin/bash

set -e

# Load environment variables
source ~/.bash_profile

base_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --region "${AWS_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-monitoring-resources" \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-file "${base_path}/../templates/create-prometheus-env.yaml" \
    --parameter-overrides \
    ECSClusterName="${ENVIRONMENT_NAME}" \
    CreateIAMRoles="True"
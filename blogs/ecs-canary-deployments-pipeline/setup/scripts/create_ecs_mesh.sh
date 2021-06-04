#!/bin/bash

set -e

source ~/.bash_profile

base_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --region "${AWS_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-clusterresources" \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-file "${base_path}/../templates/ecs-mesh.yaml" \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    Namespace="${NAMESPACE}" \
    EnvoyImage="${ENVOY_IMAGE}"

APP_URI=$(aws --region ${AWS_REGION} \
                cloudformation describe-stacks \
                --stack-name ${ENVIRONMENT_NAME}-clusterresources \
                --query "Stacks[0].Outputs[?OutputKey=='PublicLoadBalancer'].OutputValue" --output text)

echo "export APP_URI=${APP_URI}" | tee -a ~/.bash_profile

#!/bin/bash

set -ex 

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-ecs-cluster" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/ecs-cluster.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    KeyName="${KEY_PAIR_NAME}" \
    ECSServicesDomain="${SERVICES_DOMAIN}" \
    ClusterSize="${CLUSTER_SIZE:-5}"

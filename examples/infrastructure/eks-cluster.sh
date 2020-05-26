#!/bin/bash

set -ex 

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-eks-cluster" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/eks-cluster.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    KeyName="${KEY_PAIR_NAME}"
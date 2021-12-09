#!/bin/bash

set -ex

export AWS_DEFAULT_REGION=eu-west-2
export AWS_PROFILE={aws-profile}
export AWS_ACCOUNT_ID={aws-accountid}

# friendlyname-for-stack e.g. AppMeshSample
export ENVIRONMENT_NAME=CIPMeshSample
export SERVICES_DOMAIN=cip.svc.cluster.local          
export MESH_NAME=cip-mesh


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-appmesh-colorapp" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/appmesh-colorapp.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    ServicesDomain="${SERVICES_DOMAIN}" \
    AppMeshMeshName="${MESH_NAME}"

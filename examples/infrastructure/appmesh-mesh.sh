#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-appmesh-mesh" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/appmesh-mesh.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    AppMeshMeshName="${MESH_NAME}"

#!/bin/bash

set -ex 

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

aws --profile "${AWS_PROFILE}" --region "${AWS_REGION}" \
    cloudformation deploy \
    --stack-name "${ENVIRONMENT_NAME}-ec2-cluster" \
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/ec2-cluster.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    KeyName="${KEY_PAIR_NAME}" \
    ClusterSize="${CLUSTER_SIZE:-1}" \
    ECSServicesDomain="${SERVICES_DOMAIN}" \
    EnvoyImage="${ENVOY_IMAGE}" \
    AppMeshXdsEndpoint="${APPMESH_XDS_ENDPOINT}" \
    AppMeshMeshName="${MESH_NAME}" \
    ColorTellerImage="${COLOR_TELLER_IMAGE}"



#!/bin/bash

ENVOY_IMAGE=subfuzion/aws-appmesh-envoy:v1.9.1.0-prod
PROXY_ROUTER_MANAGER_IMAGE=subfuzion/aws-appmesh-proxy-route-manager:latest
COLOR_TELLER_IMAGE=subfuzion/colorteller:latest

set -ex 

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

stackname="${ENVIRONMENT_NAME}-ec2-cluster-$RANDOM"

aws --profile "${AWS_PROFILE}" --region "${AWS_REGION}" \
    cloudformation deploy \
    --stack-name ${stackname}\
    --capabilities CAPABILITY_IAM \
    --template-file "${DIR}/ec2-cluster.yaml"  \
    --parameter-overrides \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    KeyName="${KEY_PAIR_NAME}" \
    ClusterSize="${CLUSTER_SIZE:-1}" \
    ECSServicesDomain="${SERVICES_DOMAIN}" \
    EnvoyImage="${ENVOY_IMAGE}" \
    ProxyRouterManagerImage="${PROXY_ROUTER_MANAGER_IMAGE}" \
    AppMeshXdsEndpoint="${APPMESH_XDS_ENDPOINT}" \
    AppMeshMeshName="${MESH_NAME}" \
    ColorTellerImage="${COLOR_TELLER_IMAGE}"

aws --profile "${AWS_PROFILE}" --region "${AWS_REGION}" \
    cloudformation describe-stacks \
    --stack-name "${stackname}" \
    --query 'Stacks[0].Outputs[*].{OutputKey: Description, OutputValue: OutputValue}' \
    --output text

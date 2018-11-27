#!/bin/bash

set -ex 

ACTION=${1:-"create-stack"}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

err() {
    msg="Error: $1"
    print ${msg}
    code=${2:-"1"}
    exit ${code}
}

describe_virtual_node() {
    service=$1
    cmd=( aws --profile ${AWS_PROFILE} --region ${AWS_REGION} --endpoint-url ${APPMESH_FRONTEND} \
                appmesh describe-virtual-node  \
                --mesh-name ${MESH_NAME} --virtual-node-name ${service} \
                --query 'virtualNode.metadata.uid' --output text )
    node_id=$("${cmd[@]}") || err "Unable to describe node ${service}" "$?"
    echo ${service} ${node_id}
}

if [ -z ${ENVOY_IMAGE} ]; then
    err "env.ENVOY_IMAGE is not set"
fi

read COLOR_GATEWAY_NODE_NAME COLOR_GATEWAY_NODE_ID < <(describe_virtual_node "colorgateway-vn")
read COLOR_TELLER_NODE_NAME COLOR_TELLER_NODE_ID < <(describe_virtual_node "colorteller-vn")
read COLOR_TELLER_BLACK_NODE_NAME COLOR_TELLER_BLACK_NODE_ID < <(describe_virtual_node "colorteller-black-vn")
read COLOR_TELLER_BLUE_NODE_NAME COLOR_TELLER_BLUE_NODE_ID < <(describe_virtual_node "colorteller-blue-vn")
read COLOR_TELLER_RED_NODE_NAME COLOR_TELLER_RED_NODE_ID < <(describe_virtual_node "colorteller-red-vn")
read COLOR_TELLER_RED_NODE_NAME COLOR_TELLER_RED_NODE_ID < <(describe_virtual_node "colorteller-red-vn")
read REDIS_NODE_NAME REDIS_NODE_ID < <(describe_virtual_node "redis-vn")
read REDIS_PINGER_NODE_NAME REDIS_PINGER_NODE_ID < <(describe_virtual_node "redispinger-vn")

aws --profile ${AWS_PROFILE} --region ${AWS_REGION} \
    cloudformation ${ACTION} \
    --stack-name ${ENVIRONMENT_NAME}-ecs-colorapp \
    --capabilities CAPABILITY_IAM \
    --template-body file://${DIR}/ecs-colorapp.yaml  \
    --parameters \
    ParameterKey=EnvironmentName,ParameterValue=${ENVIRONMENT_NAME} \
    ParameterKey=EnvoyImage,ParameterValue=${ENVOY_IMAGE} \
    ParameterKey=AppMeshXdsEndpoint,ParameterValue=${APPMESH_XDS_ENDPOINT:-""} \
    ParameterKey=ECSServicesDomain,ParameterValue=${SERVICES_DOMAIN} \
    ParameterKey=ColorGatewayNodeId,ParameterValue="${COLOR_GATEWAY_NODE_ID}" \
    ParameterKey=ColorTellerNodeId,ParameterValue="${COLOR_TELLER_NODE_ID}" \
    ParameterKey=ColorTellerBlackNodeId,ParameterValue="${COLOR_TELLER_BLACK_NODE_ID}" \
    ParameterKey=ColorTellerBlueNodeId,ParameterValue="${COLOR_TELLER_BLUE_NODE_ID}" \
    ParameterKey=ColorTellerRedNodeId,ParameterValue="${COLOR_TELLER_RED_NODE_ID}" \
    ParameterKey=RedisNodeId,ParameterValue="${REDIS_NODE_ID}" \
    ParameterKey=RedisPingerNodeId,ParameterValue="${REDIS_PINGER_NODE_ID}"

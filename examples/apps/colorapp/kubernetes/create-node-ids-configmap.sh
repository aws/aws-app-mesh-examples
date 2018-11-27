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

read COLOR_GATEWAY_NODE_NAME COLOR_GATEWAY_NODE_ID < <(describe_virtual_node "colorgateway-vn")
read COLOR_TELLER_NODE_NAME COLOR_TELLER_NODE_ID < <(describe_virtual_node "colorteller-vn")
read COLOR_TELLER_BLACK_NODE_NAME COLOR_TELLER_BLACK_NODE_ID < <(describe_virtual_node "colorteller-black-vn")
read COLOR_TELLER_BLUE_NODE_NAME COLOR_TELLER_BLUE_NODE_ID < <(describe_virtual_node "colorteller-blue-vn")
read COLOR_TELLER_RED_NODE_NAME COLOR_TELLER_RED_NODE_ID < <(describe_virtual_node "colorteller-red-vn")

kubectl create configmap colorapp-conf \
    --from-literal=colorgateway.node.id=${COLOR_GATEWAY_NODE_ID} \
    --from-literal=colorteller.node.id=${COLOR_TELLER_NODE_ID} \
    --from-literal=colorteller-black.node.id=${COLOR_TELLER_BLACK_NODE_ID} \
    --from-literal=colorteller-blue.node.id=${COLOR_TELLER_BLUE_NODE_ID} \
    --from-literal=colorteller-red.node.id=${COLOR_TELLER_RED_NODE_ID} 

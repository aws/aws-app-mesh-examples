#!/usr/bin/env bash

set -e

if [ -z $AWS_ACCOUNT_ID ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_DEFAULT_REGION ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="$(basename ${DIR})"
STACK_NAME="appmesh-${PROJECT_NAME}"

deploy_cw_dashboards() {
    mkdir -p $DIR/_output
    MESH_NAME=${PROJECT_NAME}
    CLOUDWATCH_NAMESPACE=${CLOUDWATCH_NAMESPACE:-${PROJECT_NAME}}
    virtual_nodes=($(aws cloudformation describe-stack-resources --stack-name ${STACK_NAME} |
        jq -r '.StackResources[] | select(.ResourceType == "AWS::AppMesh::VirtualNode") | .PhysicalResourceId'))
    for vn in ${virtual_nodes[@]}; do
        VIRTUAL_NODE_NAME=$(echo $vn | sed "s#.*\/##g")
        eval "cat <<EOF
$(<${DIR}/deploy/cw-dashboard.yaml.template)
EOF
" >$DIR/_output/$VIRTUAL_NODE_NAME-cw-dashboard.yaml

        echo "Deploying stack ${VIRTUAL_NODE_NAME}-cw-dashboard, this may take a few minutes..."
        aws cloudformation deploy \
            --no-fail-on-empty-changeset \
            --stack-name ${PROJECT_NAME}-${VIRTUAL_NODE_NAME} \
            --template-file "$DIR/_output/$VIRTUAL_NODE_NAME-cw-dashboard.yaml" \
            --capabilities CAPABILITY_IAM \
            --parameter-overrides \
            "DashboardName=${PROJECT_NAME}-${VIRTUAL_NODE_NAME}"
    done
}

deploy_stacks() {
    deploy_cw_dashboards
}

delete_cfn_stack() {
    stack_name=$1
    aws cloudformation delete-stack --stack-name $stack_name
    echo "Waiting for the stack $stack_name to be deleted, this may take a few minutes..."
    aws cloudformation wait stack-delete-complete --stack-name $stack_name
    echo 'Done'
}

delete_stacks() {
    virtual_nodes=($(aws cloudformation describe-stack-resources --stack-name ${STACK_NAME} |
        jq -r '.StackResources[] | select(.ResourceType == "AWS::AppMesh::VirtualNode") | .PhysicalResourceId'))
    for vn in ${virtual_nodes[@]}; do
        VIRTUAL_NODE_NAME=$(echo $vn | sed "s#.*\/##g")
        delete_cfn_stack ${PROJECT_NAME}-${VIRTUAL_NODE_NAME}
    done
}

action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

deploy_stacks

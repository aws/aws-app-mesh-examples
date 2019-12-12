#!/usr/bin/env bash

set -e

echo "export AWS_PROFILE=${AWS_SECOND_PROFILE}"
export AWS_PROFILE=${AWS_SECOND_PROFILE}

if [ -z $AWS_PROFILE ]; then
    echo "AWS_PROFILE environment variable is not set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

deploy_infra() {
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-infra\" containing VPC and Cloud Map namespace..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-infra"\
        --template-file "${DIR}/infra.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "VPC=${SHARED_VPC}"
}

deploy_app() {
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-app\" containing ECS Tasks, Services..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-app" \
        --template-file "${DIR}/app.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "MeshOwner=${AWS_MASTER_ACCOUNT_ID}" "VPC=${SHARED_VPC}" "PrivateSubnet1=${SHARED_PRIVATE_SUBNET_1}" "PrivateSubnet2=${SHARED_PRIVATE_SUBNET_2}" "EnvoyImage=${ENVOY_IMAGE}" "BackendImage=${BACKEND_2_IMAGE}"
}

deploy_mesh() {
    # TODO: Creating VNode with preview CLI for now, replace this with CFN
    # echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-mesh\"..."
    aws appmesh-internal create-virtual-node \
        --client-token "same" \
        --mesh-name "${PROJECT_NAME}-mesh" \
        --mesh-owner "${AWS_MASTER_ACCOUNT_ID}" \
        --virtual-node-name "backend-2" \
        --spec "{\"listeners\": [{\"portMapping\": {\"port\": 80, \"protocol\":\"http\"}}], \"serviceDiscovery\": {\"dns\": {\"hostname\": \"backend.cross.${PROJECT_NAME}.local\"}}}"
}

delete_mesh() {
    # TODO: Remove this once deployed through CFN
    aws appmesh-x delete-virtual-node \
        --mesh-name "${PROJECT_NAME}-mesh" \
        --mesh-owner "${AWS_MASTER_ACCOUNT_ID}" \
        --virtual-node-name "backend-2"
}

deploy_stacks() {
    if [ -z $SHARED_VPC ]; then
        echo "SHARED_VPC environment variable is not set."
        exit 1
    fi

    if [ -z $SHARED_PRIVATE_SUBNET_1 ]; then
        echo "SHARED_PRIVATE_SUBNET_1 environment variable is not set."
        exit 1
    fi

    if [ -z $SHARED_PRIVATE_SUBNET_2 ]; then
        echo "SHARED_PRIVATE_SUBNET_2 environment variable is not set."
        exit 1
    fi

    deploy_infra
    deploy_mesh
    deploy_app
}

delete_cfn_stack() {
    stack_name=$1
    echo "Deleting Cloud Formation stack: \"${stack_name}\"..."
    aws cloudformation delete-stack --stack-name $stack_name
    echo 'Waiting for the stack to be deleted, this may take a few minutes...'
    aws cloudformation wait stack-delete-complete --stack-name $stack_name
    echo 'Done'
}

delete_stacks() {
    delete_cfn_stack "${PROJECT_NAME}-app"

    delete_cfn_stack "${PROJECT_NAME}-infra"

    # delete_cfn_stack "${PROJECT_NAME}-mesh"
    delete_mesh

    echo "all resources from this tutorial have been removed"
}

action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

deploy_stacks

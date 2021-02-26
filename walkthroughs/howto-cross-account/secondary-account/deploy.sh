#!/usr/bin/env bash

set -e

echo "Setting AWS_PROFILE=${AWS_SECONDARY_PROFILE}"
export AWS_PROFILE=${AWS_SECONDARY_PROFILE}

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
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "MeshOwner=${AWS_PRIMARY_ACCOUNT_ID}" "VPC=${SHARED_VPC}" "PrivateSubnet1=${SHARED_PRIVATE_SUBNET_1}" "PrivateSubnet2=${SHARED_PRIVATE_SUBNET_2}" "EnvoyImage=${ENVOY_IMAGE}" "BackendImage=${BACKEND_2_IMAGE}"
}

deploy_mesh() {
    echo "Creating reources in shared Mesh: \"${PROJECT_NAME}-mesh\"..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-mesh"\
        --template-file "${DIR}/mesh.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "MeshName=${PROJECT_NAME}-mesh" "MeshOwner=${AWS_PRIMARY_ACCOUNT_ID}"
}

load_primary_vpc() {
    echo "Discovering primary VPC..."
    vpc=$(aws cloudformation describe-stacks \
        --profile ${AWS_PRIMARY_PROFILE} \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='VPC'].OutputValue" \
        --output=text)
    private_subnet_1=$(aws cloudformation describe-stacks \
        --profile ${AWS_PRIMARY_PROFILE} \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='PrivateSubnet1'].OutputValue" \
        --output=text)
    private_subnet_2=$(aws cloudformation describe-stacks \
        --profile ${AWS_PRIMARY_PROFILE} \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='PrivateSubnet2'].OutputValue" \
        --output=text)

    echo "SHARED_VPC=${vpc}"
    echo "SHARED_PRIVATE_SUBNET_1=${private_subnet_1}"
    echo "SHARED_PRIVATE_SUBNET_2=${private_subnet_2}"
    export SHARED_VPC=${vpc}
    export SHARED_PRIVATE_SUBNET_1=${private_subnet_1}
    export SHARED_PRIVATE_SUBNET_2=${private_subnet_2}
}

deploy_stacks() {
    load_primary_vpc

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
    echo "Deleting route to cleanly delete ${PROJECT_NAME}-mesh"
    aws --profile ${AWS_PRIMARY_PROFILE} appmesh delete-route --mesh-name ${PROJECT_NAME}-mesh --virtual-router-name backend-vr --route-name backend-route
    delete_cfn_stack "${PROJECT_NAME}-app"
    delete_cfn_stack "${PROJECT_NAME}-infra"
    delete_cfn_stack "${PROJECT_NAME}-mesh"

    echo "all resources for secondary account have been deleted"
}

action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

deploy_stacks

#!/usr/bin/env bash

set -e

echo "Setting AWS_PROFILE=${AWS_PRIMARY_PROFILE}"
export AWS_PROFILE=${AWS_PRIMARY_PROFILE}

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
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "KeyPair=${KEY_PAIR}"
}

deploy_app() {
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-app\" containing ALB, ECS Tasks, and Services..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-app" \
        --template-file "${DIR}/app.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "EnvoyImage=${ENVOY_IMAGE}" "BackendImage=${BACKEND_1_IMAGE}"
}

deploy_mesh() {
    echo "Creating Mesh: \"${PROJECT_NAME}-mesh\"..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-mesh"\
        --template-file "${DIR}/mesh.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}"
}

enable_org_share() {
    echo "Enabling sharing with aws organization: "
    echo "If this is not a primary account, comment the below command and rerun the script."
    aws ram enable-sharing-with-aws-organization
}

share_resources() {
    echo "Sharing the Private Subnets and Mesh with ${AWS_SECONDARY_ACCOUNT_ID}"
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-share-subnets\"..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-share-resources" \
        --template-file "${DIR}/share-resources.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "ConsumerAccountId=${AWS_SECONDARY_ACCOUNT_ID}"
}

delete_cfn_stack() {
    stack_name=$1
    echo "Deleting Cloud Formation stack: \"${stack_name}\"..."
    aws cloudformation delete-stack --stack-name $stack_name
    echo 'Waiting for the stack to be deleted, this may take a few minutes...'
    aws cloudformation wait stack-delete-complete --stack-name $stack_name
    echo 'Done'
}

deploy_stacks() {
    deploy_infra
    deploy_mesh
    deploy_app
    enable_org_share
    share_resources
}

delete_stacks() {
    delete_cfn_stack "${PROJECT_NAME}-mesh"
    delete_cfn_stack "${PROJECT_NAME}-app"
    delete_cfn_stack "${PROJECT_NAME}-share-resources"
    delete_cfn_stack "${PROJECT_NAME}-infra"

    echo "all resources for primary account have been deleted"
}

action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

if [ "$action" == "deploy" ]; then
    deploy_stacks
    exit 0
fi

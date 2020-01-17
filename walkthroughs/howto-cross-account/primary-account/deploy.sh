#!/usr/bin/env bash

set -e

echo "Setting AWS_PROFILE=${AWS_PRIMARY_PROFILE}"
export AWS_PROFILE=${AWS_PRIMARY_PROFILE}

if [ -z $AWS_PROFILE ]; then
    echo "AWS_PROFILE environment variable is not set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ECR_IMAGE_PREFIX=${AWS_PRIMARY_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT_NAME}

deploy_image() {
    echo "Deploying Gateway image to ECR..."
    aws ecr describe-repositories --repository-name ${PROJECT_NAME}/gateway >/dev/null 2>&1 || aws ecr create-repository --repository-name ${PROJECT_NAME}/gateway
    docker build -t ${ECR_IMAGE_PREFIX}/gateway ${DIR}/gateway --build-arg BACKEND_SERVICE=backend.${PROJECT_NAME}.local
    # $(aws --profile ${AWS_PROFILE} ecr get-login --no-include-email)
    docker push ${ECR_IMAGE_PREFIX}/gateway
}

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
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "EnvoyImage=${ENVOY_IMAGE}" "GatewayImage=${ECR_IMAGE_PREFIX}/gateway" "BackendImage=${BACKEND_1_IMAGE}"
}

deploy_mesh() {
    echo "Creating Mesh: \"${PROJECT_NAME}-mesh\"..."
    ${DIR}/mesh/mesh.sh up
}

enable_org_share() {
    echo "Enabling sharing with aws organization: "
    echo "If this is not a primary account, comment this command and rerun the script."
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

delete_mesh() {
    echo "Deleting Mesh: \"${PROJECT_NAME}-mesh\"..."
    ${DIR}/mesh/mesh.sh down
}

delete_image() {
    echo "deleting repository \"${app}\"..."
    aws ecr delete-repository \
       --repository-name $PROJECT_NAME/gateway \
       --force
}

deploy_stacks() {
    deploy_image
    deploy_infra
    deploy_mesh
    deploy_app
    enable_org_share
    share_resources
}

delete_stacks() {
    delete_mesh
    delete_cfn_stack "${PROJECT_NAME}-app"
    delete_cfn_stack "${PROJECT_NAME}-share-resources"
    delete_cfn_stack "${PROJECT_NAME}-infra"
    delete_image

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

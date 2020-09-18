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

if [ -z $ENVOY_IMAGE ]; then
    echo "ENVOY_IMAGE environment variable is not set to App Mesh Envoy, see https://docs.aws.amazon.com/app-mesh/latest/userguide/envoy.html"
    exit 1
fi


AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="howto-outlier-detection"
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
ECR_IMAGE_PREFIX=${ECR_URL}/${PROJECT_NAME}

ecr_login() {
    if [ $AWS_CLI_VERSION -gt 1 ]; then
        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
            docker login --username AWS --password-stdin ${ECR_URL}
    else
        $(aws ecr get-login --no-include-email)
    fi
}

deploy_images() {
    ecr_login
    for app in color-app frontend-app; do
        aws ecr describe-repositories --repository-name $PROJECT_NAME/$app >/dev/null 2>&1 || aws ecr create-repository --repository-name $PROJECT_NAME/$app >/dev/null
        docker build --build-arg GO_PROXY=${GO_PROXY:-"https://proxy.golang.org"} -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/src/${app}
        docker push ${ECR_IMAGE_PREFIX}/${app}
    done
}

deploy_infra() {
    stack_name="${PROJECT_NAME}-infra"
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name $stack_name\
        --template-file "${DIR}/infrastructure.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}"
}

deploy_app() {
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-app" \
        --template-file "${DIR}/application.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "EnvoyImage=${ENVOY_IMAGE}" \
                              "ColorAppImage=${ECR_IMAGE_PREFIX}/color-app" "FrontAppImage=${ECR_IMAGE_PREFIX}/frontend-app" \
                              "ColorNodeName=mesh/${PROJECT_NAME}/virtualNode/color-node" "FrontNodeName=mesh/${PROJECT_NAME}/virtualNode/front-node" \
                              "BastionKeyName=${KEY_PAIR_NAME}"
}

delete_cfn_stack() {
    stack_name=$1
    aws cloudformation delete-stack --stack-name $stack_name
    echo 'Waiting for the stack to be deleted, this may take a few minutes...'
    aws cloudformation wait stack-delete-complete --stack-name $stack_name
    echo 'Done'
}

delete_images() {
    for app in color-app frontend-app; do
        echo "deleting repository..."
        aws ecr delete-repository \
           --repository-name $PROJECT_NAME/$app \
           --force >/dev/null
    done
}

confirm_service_linked_role() {
    aws iam get-role --role-name AWSServiceRoleForAppMesh >/dev/null
    [[ $? -eq 0 ]] ||
        (echo "Error: no service linked role for App Mesh" && exit 1)
}

print_alb_endpoint() {
    echo "Public ALB endpoint:"
    prefix=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-app" \
        --query="Stacks[0].Outputs[0].OutputValue" \
        --output=text)
    echo "${prefix}"
}

print_bastion_endpoint() {
    echo "Public bastion endpoint:"
    prefix=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-app" \
        --query="Stacks[0].Outputs[1].OutputValue" \
        --output=text)
    echo "${prefix}"
}

deploy_stacks() {

    echo "deploy images..."
    deploy_images

    echo "deploy infra..."
    deploy_infra

    echo "deploy app..."
    deploy_app

    #confirm_service_linked_role
    print_alb_endpoint
    print_bastion_endpoint
}

delete_stacks() {
    echo "delete app..."
    delete_cfn_stack "${PROJECT_NAME}-app"

    echo "delete infra..."
    delete_cfn_stack "${PROJECT_NAME}-infra"

    echo "delete images..."
    delete_images

    echo "all resources from this tutorial have been removed"
}

action=${1}
if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

deploy_stacks

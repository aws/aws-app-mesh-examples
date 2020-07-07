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
PROJECT_NAME="howto-http-headers"

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
    for app in colorapp feapp; do
        aws ecr describe-repositories --repository-name $PROJECT_NAME/$app >/dev/null 2>&1 || aws ecr create-repository --repository-name $PROJECT_NAME/$app >/dev/null
        docker build -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/${app}
        docker push ${ECR_IMAGE_PREFIX}/${app}
    done
}

deploy_infra() {
    stack_name="${PROJECT_NAME}-infra"
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name $stack_name\
        --template-file "${DIR}/infra.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}"
}

deploy_app() {
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-app" \
        --template-file "${DIR}/app.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "EnvoyImage=${ENVOY_IMAGE}" "ColorAppImage=${ECR_IMAGE_PREFIX}/colorapp" "FrontAppImage=${ECR_IMAGE_PREFIX}/feapp"
}

delete_cfn_stack() {
    stack_name=$1
    aws cloudformation delete-stack --stack-name $stack_name
    echo 'Waiting for the stack to be deleted, this may take a few minutes...'
    aws cloudformation wait stack-delete-complete --stack-name $stack_name
    echo 'Done'
}

delete_images() {
    for app in colorapp feapp; do
        image_digest=$(aws ecr describe-images \
            --repository-name="$PROJECT_NAME/$app" \
            --query="imageDetails[0].imageDigest" \
            --output=text)

        aws ecr batch-delete-image \
           --repository-name $PROJECT_NAME/$app \
           --image-ids imageDigest=$image_digest >/dev/null

        aws ecr delete-repository \
           --repository-name $PROJECT_NAME/$app >/dev/null
    done
}

confirm_service_linked_role() {
    aws iam get-role --role-name AWSServiceRoleForAppMesh >/dev/null
    [[ $? -eq 0 ]] ||
        (echo "Error: no service linked role for App Mesh" && exit 1)
}

print_endpoint() {
    echo "Public endpoint:"
    prefix=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-app" \
        --query="Stacks[0].Outputs[0].OutputValue" \
        --output=text)
    echo "${prefix}"
}

deploy_resources() {

    echo "deploy images..."
    deploy_images

    echo "deploy infra..."
    deploy_infra

    echo "deploy app..."
    deploy_app

    confirm_service_linked_role
    print_endpoint
}

delete_resources() {
    echo "delete app..."
    delete_cfn_stack "${PROJECT_NAME}-app"

    echo "delete infra..."
    delete_cfn_stack "${PROJECT_NAME}-infra"

    echo "delete images..."
    delete_images

    echo "all resources from this tutorial have been removed"
}

action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    delete_resources
    exit 0
fi

deploy_resources

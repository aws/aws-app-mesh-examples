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

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="$(basename ${DIR})"
STACK_NAME="appmesh-${PROJECT_NAME}"
GIT_COMMIT="$(git log -1 --format=%h)"
ECR_IMAGE_PREFIX=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT_NAME}

# deploy_images builds and pushes docker images for colorapp and feapp to ECR
deploy_images() {
    for f in colorapp feapp; do
        aws ecr describe-repositories --repository-name ${PROJECT_NAME}/${f} >/dev/null 2>&1 || aws ecr create-repository --repository-name ${PROJECT_NAME}/${f}
        docker build -t ${ECR_IMAGE_PREFIX}/${f}:${GIT_COMMIT} ${DIR}/src/${f}
        $(aws ecr get-login --no-include-email)
        docker push ${ECR_IMAGE_PREFIX}/${f}:${GIT_COMMIT}
    done
}

# deploy deploys infra, colorapp and feapp.
deploy() {
    stage=$1

    echo "Deploying stack ${STACK_NAME}, this may take a few minutes..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name ${STACK_NAME} \
        --template-file "$DIR/deploy/$1.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
        "ProjectName=${PROJECT_NAME}" \
        "EnvoyImage=${ENVOY_IMAGE}" \
        "ColorAppImage=${ECR_IMAGE_PREFIX}/colorapp:${GIT_COMMIT}" \
        "FrontAppImage=${ECR_IMAGE_PREFIX}/feapp:${GIT_COMMIT}"
}

delete_cfn_stack() {
    stack_name=$1
    aws cloudformation delete-stack --stack-name $stack_name
    echo "Waiting for the stack $stack_name to be deleted, this may take a few minutes..."
    aws cloudformation wait stack-delete-complete --stack-name $stack_name
    echo 'Done'
}

confirm_service_linked_role() {
    aws iam get-role --role-name AWSServiceRoleForAppMesh >/dev/null
    [[ $? -eq 0 ]] ||
        (echo "Error: no service linked role for App Mesh" && exit 1)
}

print_endpoint() {
    echo "Public endpoint:"
    prefix=$(aws cloudformation describe-stacks \
        --stack-name="${STACK_NAME}" \
        --query="Stacks[0].Outputs[?OutputKey=='FrontEndpoint'].OutputValue" \
        --output=text)
    echo "${prefix}/color"
}

deploy_stacks() {
    confirm_service_linked_role

    if [ -z $SKIP_IMAGES ]; then
        echo "deploy images..."
        deploy_images
    fi

    echo "deploy app using stage ${stage}"
    deploy "${stage}"

    print_endpoint
}

delete_stacks() {
    echo "delete stack ${STACK_NAME}..."
    delete_cfn_stack ${STACK_NAME}
}

action=${1:-"deploy"}
stage=${2:-"prelude"}
if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

deploy_stacks

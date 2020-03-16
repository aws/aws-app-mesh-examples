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
PROJECT_NAME="howto-timeout-policy"
ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
ECR_IMAGE_PREFIX=${ECR_REGISTRY}/${PROJECT_NAME}

deploy_images() {
    for app in colorapp feapp; do
        aws ecr describe-repositories --repository-name $PROJECT_NAME/$app >/dev/null 2>&1 || aws ecr create-repository --repository-name $PROJECT_NAME/$app
        docker build -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/${app}
        docker login --username AWS --password-stdin ${ECR_REGISTRY}
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
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-app\" containing ALB, ECS Tasks, and Cloud Map Services..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-app" \
        --template-file "${DIR}/app.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "EnvoyImage=${ENVOY_IMAGE}" "FrontAppImage=${ECR_IMAGE_PREFIX}/feapp" "ColorAppImage=${ECR_IMAGE_PREFIX}/colorapp"
}

deploy_mesh() {
    mesh_name="${PROJECT_NAME}"
    echo "Creating Mesh: \"${mesh_name}\"..."
    aws appmesh-preview create-mesh --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/mesh.json
    aws appmesh-preview create-virtual-node --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/frontNode.json
    aws appmesh-preview create-virtual-node --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/colorNode.json
    aws appmesh-preview create-virtual-router --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/colorRouter.json
    aws appmesh-preview create-virtual-service --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/colorService.json
    aws appmesh-preview create-route --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/colorRoute.json
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
        echo "deleting repository..."
        aws ecr delete-repository \
           --repository-name $PROJECT_NAME/$app \
           --force
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

delete_mesh() {
    mesh_name="${PROJECT_NAME}"
    echo "Deleting Mesh: \"${mesh_name}\"..."
    aws appmesh-preview delete-route --mesh-name $mesh_name --virtual-router-name color-router --route-name color-route
    aws appmesh-preview delete-virtual-service --mesh-name $mesh_name --virtual-service-name color.http.local
    aws appmesh-preview delete-virtual-router --mesh-name $mesh_name --virtual-router-name color-router
    aws appmesh-preview delete-virtual-node --mesh-name $mesh_name --virtual-node-name color-node
    aws appmesh-preview delete-virtual-node --mesh-name $mesh_name --virtual-node-name front-node
    aws appmesh-preview delete-mesh --mesh-name $mesh_name
}

deploy_stacks() {

    deploy_images

    deploy_infra

    deploy_mesh

    deploy_app

    confirm_service_linked_role

    print_endpoint
}

delete_stacks() {
    delete_cfn_stack "${PROJECT_NAME}-app"

    delete_cfn_stack "${PROJECT_NAME}-infra"
    
    delete_mesh

    delete_images

    echo "all resources from this tutorial have been removed"
}

action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

deploy_stacks

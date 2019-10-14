#!/usr/bin/env bash

set -e

if [ -z $PROJECT_NAME ]; then
    echo "PROJECT_NAME environment variable is not set."
    exit 1
fi

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

if [ -z $KEY_PAIR ]; then
    echo "KEY_PAIR environment variable is not set. This must be the name of an SSH key pair, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ECR_IMAGE_PREFIX=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT_NAME}

deploy_images() {
    echo "Deploying Color Client and Color Server images to ECR..."
    for app in color_client color_server; do
        aws ecr describe-repositories --repository-name ${PROJECT_NAME}/${app} >/dev/null 2>&1 || aws ecr create-repository --repository-name ${PROJECT_NAME}/${app}
        docker build -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/${app} --build-arg GO_PROXY=${GO_PROXY:-"https://proxy.golang.org"}
        $(aws ecr get-login --no-include-email)
        docker push ${ECR_IMAGE_PREFIX}/${app}
    done
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
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-app\" containing ALB, ECS Tasks, and Cloud Map Services..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-app" \
        --template-file "${DIR}/app.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "EnvoyImage=${ENVOY_IMAGE}" "ColorClientImage=${ECR_IMAGE_PREFIX}/color_client" "ColorServerImage=${ECR_IMAGE_PREFIX}/color_server"
}

deploy_mesh() {
    mesh_name="${PROJECT_NAME}-mesh"
    echo "Creating Mesh: \"${mesh_name}\"..."
    aws appmesh-preview create-mesh --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/mesh.json
    aws appmesh-preview create-virtual-node --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/color-client-node.json
    aws appmesh-preview create-virtual-node --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/color-server-red-node.json
    aws appmesh-preview create-virtual-node --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/color-server-green-node.json
    aws appmesh-preview create-virtual-node --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/color-server-blue-node.json
    aws appmesh-preview create-virtual-router --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/virtual-router.json
    aws appmesh-preview create-virtual-service --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/virtual-service.json
    aws appmesh-preview create-route --mesh-name $mesh_name --cli-input-json file://${DIR}/mesh/route-red.json
}

print_bastion() {
    echo "Bastion endpoint:"
    ip=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='BastionIp'].OutputValue" \
        --output=text)
    echo "${ip}"
}

print_endpoint() {
    echo "Public endpoint:"
    prefix=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-app" \
        --query="Stacks[0].Outputs[?OutputKey=='PublicEndpoint'].OutputValue" \
        --output=text)
    echo "${prefix}"
}

deploy_stacks() {
    deploy_images
    deploy_infra
    deploy_mesh
    deploy_app

    print_bastion
    print_endpoint
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
    mesh_name="${PROJECT_NAME}-mesh"
    echo "Deleting Mesh: \"${mesh_name}\"..."
    aws appmesh-preview delete-route --mesh-name $mesh_name --virtual-router-name virtual-router --route-name route
    aws appmesh-preview delete-virtual-service --mesh-name $mesh_name --virtual-service-name color_server.http2.local
    aws appmesh-preview delete-virtual-router --mesh-name $mesh_name --virtual-router-name virtual-router
    aws appmesh-preview delete-virtual-node --mesh-name $mesh_name --virtual-node-name color_server-red
    aws appmesh-preview delete-virtual-node --mesh-name $mesh_name --virtual-node-name color_server-green
    aws appmesh-preview delete-virtual-node --mesh-name $mesh_name --virtual-node-name color_server-blue
    aws appmesh-preview delete-virtual-node --mesh-name $mesh_name --virtual-node-name color_client
    aws appmesh-preview delete-mesh --mesh-name $mesh_name
}

delete_images() {
    for app in color_client color_server; do
        echo "deleting repository \"${app}\"..."
        aws ecr delete-repository \
           --repository-name $PROJECT_NAME/$app \
           --force
    done
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

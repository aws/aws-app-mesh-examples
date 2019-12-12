#!/usr/bin/env bash

set -e

echo "export AWS_PROFILE=${AWS_MASTER_PROFILE}"
export AWS_PROFILE=${AWS_MASTER_PROFILE}

if [ -z $AWS_PROFILE ]; then
    echo "AWS_PROFILE environment variable is not set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ECR_IMAGE_PREFIX=${AWS_MASTER_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT_NAME}

deploy_image() {
    echo "Deploying Gateway image to ECR..."
    aws ecr describe-repositories --repository-name ${PROJECT_NAME}/gateway >/dev/null 2>&1 || aws ecr create-repository --repository-name ${PROJECT_NAME}/gateway
    docker build -t ${ECR_IMAGE_PREFIX}/gateway ${DIR}/gateway --build-arg BACKEND_SERVICE=backend.${PROJECT_NAME}.local
    $(aws ecr get-login --no-include-email)
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
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-mesh\"..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-mesh" \
        --template-file "${DIR}/mesh.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}"
}

enable_org_share() {
    echo "Enabling sharing with aws organization: "
    echo "If this is not a master account, comment this command and rerun the script."
    aws ram enable-sharing-with-aws-organization
}

share_subnets() {
    echo "Sharing the Private Subnets with ${AWS_SECOND_ACCOUNT_ID}"
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-share-subnets\"..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name "${PROJECT_NAME}-share-subnets" \
        --template-file "${DIR}/share-subnets.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides "ProjectName=${PROJECT_NAME}" "ConsumerAccountId=${AWS_SECOND_ACCOUNT_ID}"
}

share_mesh() {
    # TODO: Add this once appmesh / appmesh-preview is whitelisted by RAM
    echo "Sharing the mesh with ${PROJECT_NAME}-mesh with ${AWS_SECOND_ACCOUNT_ID}"
    sleep 10 # Sleeping while sharing the mesh manually
}

print_bastion() {
    echo "Bastion endpoint:"
    ip=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='BastionIp'].OutputValue" \
        --output=text)
    echo "export BASTION_IP=${ip}"
    export BASTION_IP=${ip}
}

print_vpc() {
    echo "Printing shared VPC and Subnets, export these values."
    vpc=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='VPC'].OutputValue" \
        --output=text)
    private_subnet_1=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='PrivateSubnet1'].OutputValue" \
        --output=text)
    private_subnet_2=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-infra" \
        --query="Stacks[0].Outputs[?OutputKey=='PrivateSubnet2'].OutputValue" \
        --output=text)

    echo "export SHARED_VPC=${vpc}"
    echo "export SHARED_PRIVATE_SUBNET_1=${private_subnet_1}"
    echo "export SHARED_PRIVATE_SUBNET_2=${private_subnet_2}"
    export SHARED_VPC=${vpc}
    export SHARED_PRIVATE_SUBNET_1=${private_subnet_1}
    export SHARED_PRIVATE_SUBNET_2=${private_subnet_2}
}

print_endpoint() {
    echo "Public endpoint:"
    prefix=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-app" \
        --query="Stacks[0].Outputs[?OutputKey=='PublicEndpoint'].OutputValue" \
        --output=text)
    echo "export DNS_ENDPOINT=${prefix}"
    export DNS_ENDPOINT=${prefix}
}

deploy_stacks() {
    deploy_image
    deploy_infra
    deploy_mesh
    deploy_app
    enable_org_share
    share_subnets
    share_mesh

    print_bastion
    print_vpc
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

delete_image() {
    echo "deleting repository \"${app}\"..."
    aws ecr delete-repository \
       --repository-name $PROJECT_NAME/gateway \
       --force
}

delete_stacks() {

    delete_cfn_stack "${PROJECT_NAME}-app"

    delete_cfn_stack "${PROJECT_NAME}-share-subnets"

    delete_cfn_stack "${PROJECT_NAME}-infra"

    delete_cfn_stack "${PROJECT_NAME}-mesh"

    delete_image

    echo "all resources from this tutorial have been removed"
}

action=${1:-"deploy"}
if [ "$action" == "delete" ]; then
    delete_stacks
    exit 0
fi

deploy_stacks

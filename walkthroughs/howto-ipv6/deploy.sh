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

if [ -z $KEY_PAIR_NAME ]; then
    echo "KEY_PAIR_NAME environment variable is not set. This must be the name of an SSH key pair, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
ECR_IMAGE_PREFIX="${ECR_URL}/${PROJECT_NAME}"
AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)

ecr_login() {
    if [ $AWS_CLI_VERSION -gt 1 ]; then
        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
            docker login --username AWS --password-stdin ${ECR_URL}
    else
        $(aws ecr get-login --no-include-email)
    fi
}

deploy_images() {
    echo "Deploying Color Client and Color Server images to ECR..."
    ecr_login
    for app in color_client color_server_v4 color_server_dual color_server_v6; do
        aws ecr describe-repositories --region ${AWS_DEFAULT_REGION} --repository-name ${PROJECT_NAME}/${app} >/dev/null 2>&1 || aws ecr create-repository --region ${AWS_DEFAULT_REGION} --repository-name ${PROJECT_NAME}/${app} >/dev/null
        docker build -t ${ECR_IMAGE_PREFIX}/${app} ${DIR}/${app} --build-arg GO_PROXY=${GO_PROXY:-"https://proxy.golang.org"}
        docker push ${ECR_IMAGE_PREFIX}/${app}
    done
}

deploy_cluster() {
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-ecs-cluster\" containing ECS cluster, Cloud Map namespace and bastion host..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --region "${AWS_DEFAULT_REGION}" \
        --stack-name "${PROJECT_NAME}-ecs-cluster" \
        --template-file "${DIR}/infra/ecs-cluster.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
        ProjectName="${PROJECT_NAME}" \
        KeyName="${KEY_PAIR_NAME}" \
        ECSServicesDomain="${SERVICES_DOMAIN}"
}

deploy_vpc() {
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-vpc\" containing VPC and subnets..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --region "${AWS_DEFAULT_REGION}" \
        --stack-name "${PROJECT_NAME}-vpc" \
        --template-file "${DIR}/infra/vpc.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
        ProjectName="${PROJECT_NAME}" 
}

deploy_cloud_service() {
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-cloud-ecs-service\" containing ECS service, task definitions, and tasks..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --region "${AWS_DEFAULT_REGION}" \
        --stack-name "${PROJECT_NAME}-cloud-ecs-service" \
        --template-file "${DIR}/cloud/ecs-service.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
        ProjectName="${PROJECT_NAME}" \
        ECSServicesDomain="${SERVICES_DOMAIN}" \
        AppMeshMeshName="${MESH_NAME}-cloud-mesh" \
        EnvoyImage="${ENVOY_IMAGE}"
}

deploy_dns_service() {
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-dns-ecs-service\" containing ECS service, task definitions, and tasks..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --region "${AWS_DEFAULT_REGION}" \
        --stack-name "${PROJECT_NAME}-dns-ecs-service"\
        --template-file "${DIR}/dns/ecs-service.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
        ProjectName="${PROJECT_NAME}" \
        ECSServicesDomain="${SERVICES_DOMAIN}" \
        AppMeshMeshName="${MESH_NAME}-dns-mesh" \
        EnvoyImage="${ENVOY_IMAGE}"
}

deploy_mesh() {
    deployment_type=$1
    template=$2
    echo "Deploying Cloud Formation stack: \"${PROJECT_NAME}-${deployment_type}-mesh\"..."
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --region "${AWS_DEFAULT_REGION}" \
        --stack-name "${PROJECT_NAME}-${deployment_type}-mesh" \
        --template-file "${DIR}/${deployment_type}/mesh/${template}.yaml" \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides \
        AppMeshMeshName="${MESH_NAME}-${deployment_type}-mesh" \
        ProjectName="${PROJECT_NAME}"    
}

print_bastion() {
    echo "Bastion endpoint:"
    ip=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-ecs-cluster" \
        --region ${AWS_DEFAULT_REGION} \
        --query="Stacks[0].Outputs[?OutputKey=='BastionIP'].OutputValue" \
        --output=text)
    echo "${ip}"
}

print_endpoint() {
    echo "Public endpoint:"
    prefix=$(aws cloudformation describe-stacks \
        --stack-name="${PROJECT_NAME}-$1-ecs-service" \
        --region ${AWS_DEFAULT_REGION} \
        --query="Stacks[0].Outputs[?OutputKey=='ColorAppEndpoint'].OutputValue" \
        --output=text)
    echo "${prefix}"
}

deploy_infra() {
    deploy_images
    deploy_vpc
    deploy_cluster

    print_bastion
}

deploy_cloud() {
    deploy_mesh "cloud" "mesh-v4-only"
    deploy_cloud_service

    print_endpoint "cloud"
}

deploy_dns() {
    deploy_mesh "dns" "mesh-v4-only"
    deploy_dns_service

    print_endpoint "dns"
}

update_mesh() {
    deployment_type=$1
    case $2 in
        v6_preferred)
            template="mesh-v6-preferred"
            ;;
        v4_preferred)
            template="mesh-v4-preferred"
            ;;
        v6_only)
            template="mesh-v6-only"
            ;;
        override)
            template="override-mesh-preference"
            ;;
        custom)
            template="custom-preference"
            ;;
        *)
            template="mesh-v4-only"  
            ;;                                  
    esac

    deploy_mesh ${deployment_type} ${template}
}

delete_cfn_stack() {
    stack_name=$1
    echo "Deleting Cloud Formation stack: \"${stack_name}\"..."
    aws cloudformation delete-stack --stack-name $stack_name --region ${AWS_DEFAULT_REGION}
    echo 'Waiting for the stack to be deleted, this may take a few minutes...'
    aws cloudformation wait stack-delete-complete --stack-name $stack_name --region ${AWS_DEFAULT_REGION}
    echo 'Done'
}

delete_images() {
    for app in color_client color_server_v4 color_server_dual color_server_v6; do
        echo "deleting repository \"${app}\"..."
        aws ecr delete-repository \
           --repository-name $PROJECT_NAME/$app \
           --region ${AWS_DEFAULT_REGION} \
           --force >/dev/null
    done
}

delete_dns() {
    delete_cfn_stack "${PROJECT_NAME}-dns-ecs-service"

    delete_cfn_stack "${PROJECT_NAME}-dns-mesh"
}

delete_cloud() {
    delete_cfn_stack "${PROJECT_NAME}-cloud-ecs-service"

    delete_cfn_stack "${PROJECT_NAME}-cloud-mesh"
}

delete_infra() {
    delete_cfn_stack "${PROJECT_NAME}-ecs-cluster"

    delete_cfn_stack "${PROJECT_NAME}-vpc"

    delete_images

    echo "all resources from this tutorial have been removed"
}

action=${1:-"infra"}

if [ "$action" == "infra" ]; then
    deploy_infra
    exit 0
fi

if [ "$action" == "cloud-service" ]; then
    deploy_cloud
    exit 0
fi

if [ "$action" == "dns-service" ]; then
    deploy_dns
    exit 0
fi

if [ "$action" == "update-mesh" ]; then
    update_mesh $2 $3
    exit 0
fi

if [ "$action" == "delete-infra" ]; then
    delete_infra
    exit 0
fi

if [ "$action" == "delete-cloud-service" ]; then
    delete_cloud
    exit 0
fi

if [ "$action" == "delete-dns-service" ]; then
    delete_dns
    exit 0
fi

echo "invalid option chosen"

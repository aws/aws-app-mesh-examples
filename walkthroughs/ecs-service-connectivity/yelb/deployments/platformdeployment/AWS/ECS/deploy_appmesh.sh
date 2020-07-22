#!/bin/bash

set -ex

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
source ${DIR}/.settings

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

if [ -z $VPC ]; then
    echo "VPC environment variable is not set. Before proceeding setup a VPC with 2 public subnets and continue."
    exit 1
fi

if [ -z $PUBLIC_SUBNET_1 ]; then
    echo "PUBLIC_SUBNET_1 environment variable is not set. Before proceeding setup a VPC with 2 public subnets and continue."
    exit 1
fi


if [ -z $PUBLIC_SUBNET_2 ]; then
    echo "PUBLIC_SUBNET_2 environment variable is not set. Before proceeding setup a VPC with 2 public subnets and continue."
    exit 1
fi


PROJECT_NAME=yelb
ECR_IMAGE_PREFIX=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT_NAME}
YELB_UI_SRC="${DIR}/../../../../yelb-ui"
YELB_UI_IMAGE="${ECR_IMAGE_PREFIX}/yelb-ui:$(git log -1 --format=%h ${YELB_UI_SRC})"
YELB_APP_SRC="${DIR}/../../../../yelb-appserver"
YELB_APP_IMAGE="${ECR_IMAGE_PREFIX}/yelb-appserver:$(git log -1 --format=%h ${YELB_APP_SRC})"


deploy_images() {
    for f in yelb-ui; do
        aws ecr describe-repositories --repository-name ${PROJECT_NAME}/${f} >/dev/null 2>&1 || aws ecr create-repository --repository-name ${PROJECT_NAME}/${f}
    done

    $(aws ecr get-login --no-include-email)
    docker build -t ${YELB_UI_IMAGE} ${YELB_UI_SRC} && docker push ${YELB_UI_IMAGE}
    
    for f in yelb-appserver; do
        aws ecr describe-repositories --repository-name ${PROJECT_NAME}/${f} >/dev/null 2>&1 || aws ecr create-repository --repository-name ${PROJECT_NAME}/${f}
    done

    $(aws ecr get-login --no-include-email)
    docker build -t ${YELB_APP_IMAGE} ${YELB_APP_SRC} && docker push ${YELB_APP_IMAGE}
    
} 

#create ecs cluster
aws ecs create-cluster \
    --cluster-name yelb
    
#create security group for yelb-db
#create-security-group --description "yelb-db security group" --group-name YelbDbSecurityGroup --vpc-id $VPC


#create aurora postgresql for yelb-db
    


deploy_images
aws cloudformation deploy \
    --capabilities CAPABILITY_IAM --stack-name yelb-fargate  \
    --template-file $DIR/yelb-cloudformation-ECS-AppMesh-deployment.yaml \
    --parameter-overrides \
    "Cluster=yelb" \
    "VPC=${VPC}" \
    "PublicSubnetOne=${PUBLIC_SUBNET_1}" \
    "PublicSubnetTwo=${PUBLIC_SUBNET_2}" \
    "LaunchType=FARGATE" \
    "Domain=yelb.local" \
    "CountOfUiTasks=2" \
    "CountOfAppserverTasks=3" \
    "PublicIP=ENABLED" \
    "Mesh=yelb" \
    "EnvoyImage=${ENVOY_IMAGE}" \
    "YelbUIImage=${YELB_UI_IMAGE}"\
    "YelbAppServerImage=${YELB_APP_IMAGE}"

#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $COLOR_APP_ENVOY_IMAGE_NAME ]; then
    echo "COLOR_APP_ENVOY_IMAGE_NAME environment variable is not set"
    exit 1
fi

if [ -z $ENVOY_IMAGE ]; then
    echo "ENVOY_IMAGE environment variable is not set"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

ENVOY_ACCOUNT_PASSWORD="$(aws ecr get-authorization-token --registry-ids 840364872350 --query 'authorizationData[0].authorizationToken' --output text)"
ENVOY_ACCOUNT_ECR_REGISTRY="840364872350.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
echo "$ENVOY_ACCOUNT_PASSWORD" | docker login --username AWS --password-stdin ${ENVOY_ACCOUNT_ECR_REGISTRY}

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
IMAGE="${ECR_REGISTRY}/${COLOR_APP_ENVOY_IMAGE_NAME}:latest"

# build
docker build -t $IMAGE $DIR --build-arg ENVOY_IMAGE=$ENVOY_IMAGE

# push
docker login --username AWS --password-stdin ${ECR_REGISTRY}
docker push $IMAGE

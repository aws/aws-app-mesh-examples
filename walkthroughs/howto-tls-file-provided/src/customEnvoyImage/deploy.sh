#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $AWS_ACCOUNT_ID ]; then
    echo "AWS_ACCOUNT_ID environment variable is not set."
    exit 1
fi

if [ -z $AWS_DEFAULT_REGION ]; then
    echo "AWS_DEFAULT_REGION environment variable is not set."
    exit 1
fi

if [ -z $COLOR_APP_ENVOY_IMAGE_NAME ]; then
    echo "COLOR_APP_ENVOY_IMAGE_NAME environment variable is not set"
    exit 1
fi

if [ -z $ENVOY_IMAGE ]; then
    echo "ENVOY_IMAGE environment variable is not set"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)

ENVOY_REGISTRY_ID=840364872350
DEMO_ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
IMAGE="${DEMO_ECR_URL}/${COLOR_APP_ENVOY_IMAGE_NAME}:latest"

ecr_login() {
    REGISTRY_ID=$1

    if [ $AWS_CLI_VERSION -gt 1 ]; then
	REGISTRY_URL="${REGISTRY_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
            docker login --username AWS --password-stdin ${REGISTRY_URL}
    else
	$(aws ecr get-login --no-include-email --registry-id ${REGISTRY_ID})
    fi
}

# login to envoy registry for pull
ecr_login $ENVOY_REGISTRY_ID

# build and push
docker build -t $IMAGE $DIR --build-arg ENVOY_IMAGE=$ENVOY_IMAGE
ecr_login $AWS_ACCOUNT_ID
docker push $IMAGE

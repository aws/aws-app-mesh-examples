#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $COLOR_GATEWAY_IMAGE_NAME ]; then
    echo "COLOR_GATEWAY_IMAGE_NAME environment variable is not set"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"

IMAGE="${ECR_URL}/${COLOR_GATEWAY_IMAGE_NAME}:latest"

# build
docker build -t $IMAGE $DIR --build-arg GO_PROXY=${GO_PROXY:-"https://proxy.golang.org"}


# ECR login
AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)

if [ $AWS_CLI_VERSION -eq 1 ]; then
    $(aws ecr get-login --no-include-email)
elif [ $AWS_CLI_VERSION -eq 2 ]; then
    aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_URL}
else
    echo "Invalid AWS CLI version"
    exit 1
fi

# push
docker push $IMAGE


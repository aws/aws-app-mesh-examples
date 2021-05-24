#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $COLOR_TELLER_IMAGE_NAME ]; then
    echo "COLOR_TELLER_IMAGE_NAME environment variable is not set"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
IMAGE="${ECR_URL}/${COLOR_TELLER_IMAGE_NAME}:latest"

# build
docker build -t $IMAGE $DIR --build-arg GO_PROXY=${GO_PROXY:-"https://proxy.golang.org"}

# login
AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d. -f1)
if [ $AWS_CLI_VERSION -gt 1 ]; then
    aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
         docker login --username AWS --password-stdin ${ECR_URL}
else
    $(aws ecr get-login --no-include-email)
fi

# push
docker push $IMAGE

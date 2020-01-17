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

$(aws ecr get-login --no-include-email --registry-id 840364872350)

IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${COLOR_APP_ENVOY_IMAGE_NAME}:latest"

# build
docker build -t $IMAGE $DIR --build-arg ENVOY_IMAGE=$ENVOY_IMAGE

# push
$(aws ecr get-login --no-include-email)
docker push $IMAGE

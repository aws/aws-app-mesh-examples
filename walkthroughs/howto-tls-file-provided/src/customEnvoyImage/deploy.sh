#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $COLOR_TELLER_IMAGE_NAME ]; then
    echo "COLOR_TELLER_IMAGE_NAME environment variable is not set"
    exit 1
fi

if [ -z $AWS_ENVOY_IMAGE ]; then
    echo "AWS_ENVOY_IMAGE environment variable is not set"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

$(aws ecr get-login --no-include-email --registry-id 840364872350)

IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${COLOR_TELLER_IMAGE_NAME}-envoy:latest"

# build
docker build -t $IMAGE $DIR -f $DIR/Dockerfile-envoy-wrapper --build-arg AWS_ENVOY_IMAGE=$AWS_ENVOY_IMAGE

# push
$(aws ecr get-login --no-include-email)
docker push $IMAGE

echo "export ENVOY_IMAGE=$IMAGE"

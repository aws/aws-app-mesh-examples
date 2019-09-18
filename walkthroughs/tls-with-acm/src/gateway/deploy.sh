#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $GATEWAY_IMAGE_NAME ]; then
    echo "GATEWAY_IMAGE_NAME environment variable is not set"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${GATEWAY_IMAGE_NAME}:latest"

# build
docker build -t $IMAGE $DIR

# push
$(aws ecr get-login --no-include-email)
docker push $IMAGE

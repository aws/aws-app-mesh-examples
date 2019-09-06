#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $COLOR_GATEWAY_IMAGE ]; then
    echo "COLOR_GATEWAY_IMAGE environment variable is not set"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# build
docker build -t $COLOR_GATEWAY_IMAGE $DIR

# push
if [ -z $AWS_PROFILE  ]; then
    $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
else
    $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
fi
docker push $COLOR_GATEWAY_IMAGE

#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $COLOR_GATEWAY_IMAGE ]; then
    echo "COLOR_GATEWAY_IMAGE environment variable is not set"
    exit 1
fi

# build
docker build -t $COLOR_GATEWAY_IMAGE .

# push
$(aws ecr get-login --no-include-email)
docker push $COLOR_GATEWAY_IMAGE

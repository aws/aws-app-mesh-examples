#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $COLOR_TELLER_IMAGE ]; then
    echo "COLOR_TELLER_IMAGE environment variable is not set"
    exit 1
fi

# build
docker build -t $COLOR_TELLER_IMAGE .

# push
$(aws ecr get-login --no-include-email --region $AWS_REGION --profile $AWS_PROFILE)
docker push $COLOR_TELLER_IMAGE

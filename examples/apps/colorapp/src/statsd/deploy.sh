#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $STATSD_IMAGE ]; then
    echo "STATSD_IMAGE environment variable is not set"
    exit 1
fi

# build
docker build -t $STATSD_IMAGE .

# push
if [ -z $AWS_PROFILE  ]; then
    $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
else
    $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION --profile $AWS_PROFILE)
fi
docker push $STATSD_IMAGE

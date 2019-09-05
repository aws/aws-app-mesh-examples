#!/usr/bin/env bash
# vim:syn=sh:ts=4:sw=4:et:ai

set -ex

if [ -z $COLOR_TELLER_IMAGE ]; then
    echo "COLOR_TELLER_IMAGE environment variable is not set"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# build
docker build -t $COLOR_TELLER_IMAGE $DIR

# push
$(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
docker push $COLOR_TELLER_IMAGE

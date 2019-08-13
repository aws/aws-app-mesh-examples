#!/bin/bash

set -e

if [ -z "${AWS_ACCOUNT_ID}" ]; then
    echo "AWS_ACCOUNT_ID must be set."
    exit 1
fi

if [ -z "${AWS_DEFAULT_REGION}" ]; then
    echo "AWS_DEFAULT_REGION must be set."
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

APP_NAMESPACE=${APP_NAMESPACE:-"headerpriority"}
COLOR_IMAGE_NAME="${APP_NAMESPACE}-colorapp"
COLOR_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${COLOR_IMAGE_NAME}"
FRONT_IMAGE_NAME="${APP_NAMESPACE}-feapp"
FRONT_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${FRONT_IMAGE_NAME}"

if [ -z "${SKIP_CREATE_REPOSITORIES}"]; then
    $(aws ecr create-repository --repository-name ${COLOR_IMAGE_NAME})
    $(aws ecr create-repository --repository-name ${FRONT_IMAGE_NAME})
fi

$(aws ecr get-login --no-include-email)

docker build -t ${COLOR_IMAGE} colorapp
docker push ${COLOR_IMAGE}
echo "Done creating ${COLOR_IMAGE_NAME} image"

docker build -t ${FRONT_IMAGE} feapp
docker push ${FRONT_IMAGE}
echo "Done creating ${FRONT_IMAGE_NAME} image"
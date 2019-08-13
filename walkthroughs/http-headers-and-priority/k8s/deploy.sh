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

if [ -z "${MESH_NAME}" ]; then
    echo "MESH_NAME must be set."
    exit 1
fi

APP_NAMESPACE=${APP_NAMESPACE:-"headerpriority"}
COLOR_IMAGE_NAME="${APP_NAMESPACE}-colorapp"
COLOR_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${COLOR_IMAGE_NAME}"
FRONT_IMAGE_NAME="${APP_NAMESPACE}-feapp"
FRONT_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${FRONT_IMAGE_NAME}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
OUT_DIR="${DIR}/_output/"
mkdir -p ${OUT_DIR}

for f in mesh app; do
    eval "cat <<EOF
$(<${DIR}/${f}.yaml.template)
EOF" >${OUT_DIR}/${f}.yaml

    kubectl apply -f ${OUT_DIR}/${f}.yaml
done
